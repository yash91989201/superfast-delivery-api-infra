import * as pulumi from "@pulumi/pulumi";
import * as fs from "fs";
import * as aws from "@pulumi/aws";
import * as tls from "@pulumi/tls";
import {
  bastionHostAMI,
  bastionHostSSHKeyName,
  clusterName,
  k8sNodeAMI,
} from "./constants";
import { createRequire } from "module";
const require = createRequire(import.meta.url);

const k8sMasterNodeRolePolicyJSON = require("./k8s-master-node-role-policy.json");
const k8sWorkerNodeRolePolicyJSON = require("./k8s-worker-node-role-policy.json");

const k8sSSHKey = new tls.PrivateKey("k8s-ssh-key", {
  algorithm: "ED25519",
});

// Create an AWS Key Pair
const k8sSSHKeyPair = new aws.ec2.KeyPair("k8s-ssh-key-pair", {
  publicKey: k8sSSHKey.publicKeyOpenssh,
});

const bastionHostScript = fs.readFileSync(
  "./user-data/bastion-host.sh",
  "utf-8",
);

const bastionHostUserData = pulumi.interpolate`${bastionHostScript.replace("{{K8S_SSH_KEY}}", k8sSSHKey.privateKeyPem.get())}`;

const availabilityZones = await aws.getAvailabilityZones({
  state: "available",
});

const az1 = availabilityZones.names[0];
const az2 = availabilityZones.names[1];

const vpc = new aws.ec2.Vpc("superfast-delivery", {
  cidrBlock: "10.0.0.0/16",
  enableDnsHostnames: true,
  enableDnsSupport: true,
  tags: {
    Name: "superfast-delivery",
  },
});

const eip = new aws.ec2.Eip("eip", {
  domain: "vpc",
});

new aws.ec2.DefaultSubnet("default-subnet", {
  availabilityZone: az1,
  tags: {
    Name: "default-subnet",
  },
});

const publicSubnet01 = new aws.ec2.Subnet("public-subnet-01", {
  vpcId: vpc.id,
  cidrBlock: "10.0.0.0/20",
  mapPublicIpOnLaunch: true,
  availabilityZone: az1,
  tags: {
    Name: "public-subnet-01",
    [`kubernetes.io/cluster/${clusterName}`]: "shared",
  },
});

const publicSubnet02 = new aws.ec2.Subnet("public-subnet-02", {
  vpcId: vpc.id,
  cidrBlock: "10.0.16.0/20",
  mapPublicIpOnLaunch: true,
  availabilityZone: az2,
  tags: {
    Name: "public-subnet-02",
    [`kubernetes.io/cluster/${clusterName}`]: "shared",
  },
});

const privateSubnet01 = new aws.ec2.Subnet("private-subnet-01", {
  vpcId: vpc.id,
  cidrBlock: "10.0.128.0/20",
  availabilityZone: az1,
  tags: {
    Name: "private-subnet-01",
    [`kubernetes.io/cluster/${clusterName}`]: "shared",
  },
});

const privateSubnet02 = new aws.ec2.Subnet("private-subnet-02", {
  vpcId: vpc.id,
  cidrBlock: "10.0.144.0/20",
  availabilityZone: az2,
  tags: {
    Name: "private-subnet-02",
    [`kubernetes.io/cluster/${clusterName}`]: "shared",
  },
});

const igw = new aws.ec2.InternetGateway("igw", {
  vpcId: vpc.id,
  tags: {
    Name: "igw",
  },
});

const nat = new aws.ec2.NatGateway("nat-gtw", {
  allocationId: eip.id,
  subnetId: publicSubnet01.id,
  tags: {
    Name: "nat-gtw",
  },
});

// Set default route table
new aws.ec2.DefaultRouteTable("default-rtb", {
  defaultRouteTableId: vpc.defaultRouteTableId,
  routes: [
    {
      cidrBlock: "0.0.0.0/0",
      gatewayId: igw.id,
    },
    {
      cidrBlock: "10.0.0.0/16",
      gatewayId: "local",
    },
  ],
  tags: {
    Name: "default-rtb",
  },
});

const publicRtb01 = new aws.ec2.RouteTable("public-rtb-01", {
  vpcId: vpc.id,
  routes: [
    {
      cidrBlock: "0.0.0.0/0",
      gatewayId: igw.id,
    },
    {
      cidrBlock: "10.0.0.0/16",
      gatewayId: "local",
    },
  ],
  tags: {
    Name: "public-rtb-01",
  },
});

const privateRtb01 = new aws.ec2.RouteTable("private-rtb-01", {
  vpcId: vpc.id,
  routes: [
    {
      cidrBlock: "0.0.0.0/0",
      natGatewayId: nat.id,
    },
    {
      cidrBlock: "10.0.0.0/16",
      gatewayId: "local",
    },
  ],
  tags: {
    Name: "private-rtb-01",
  },
});

const privateRtb02 = new aws.ec2.RouteTable("private-rtb-02", {
  vpcId: vpc.id,
  routes: [
    {
      cidrBlock: "0.0.0.0/0",
      natGatewayId: nat.id,
    },
    {
      cidrBlock: "10.0.0.0/16",
      gatewayId: "local",
    },
  ],
  tags: {
    Name: "private-rtb-02",
  },
});

new aws.ec2.RouteTableAssociation("public-rtba-01", {
  subnetId: publicSubnet01.id,
  routeTableId: publicRtb01.id,
});

new aws.ec2.RouteTableAssociation("public-rtba-02", {
  subnetId: publicSubnet02.id,
  routeTableId: publicRtb01.id,
});

new aws.ec2.RouteTableAssociation("private-rtba-01", {
  subnetId: privateSubnet01.id,
  routeTableId: privateRtb01.id,
});

new aws.ec2.RouteTableAssociation("private-rtba-02", {
  subnetId: privateSubnet02.id,
  routeTableId: privateRtb02.id,
});

new aws.ec2.DefaultSecurityGroup("default-sg", {
  vpcId: vpc.id,
  ingress: [
    {
      protocol: "-1",
      self: true,
      fromPort: 0,
      toPort: 0,
    },
  ],
  egress: [
    {
      fromPort: 0,
      toPort: 0,
      protocol: "-1",
      cidrBlocks: ["0.0.0.0/0"],
    },
  ],
  tags: {
    Name: "default-sg",
  },
});

const k8sApiServerLbSg = new aws.ec2.SecurityGroup("k8s-api-server-lb-sg", {
  name: "k8s-api-server-lb-sg",
  description: "Security group for k8s api server private load balancer",
  vpcId: vpc.id,
  tags: {
    Name: "k8s-api-server-lb-sg",
  },
});

new aws.vpc.SecurityGroupIngressRule(
  "k8s-api-server-lb-sg-allow-6443-inbound",
  {
    securityGroupId: k8sApiServerLbSg.id,
    cidrIpv4: "0.0.0.0/0",
    ipProtocol: "tcp",
    fromPort: 6443,
    toPort: 6443,
  },
);

new aws.vpc.SecurityGroupEgressRule("k8s-api-server-lb-sg-allow-all-outbound", {
  securityGroupId: k8sApiServerLbSg.id,
  cidrIpv4: "0.0.0.0/0",
  ipProtocol: "-1",
});

const bastionHostSg = new aws.ec2.SecurityGroup("bastion-host-sg", {
  name: "bastion-host-sg",
  description: "Security group for public bastion host",
  vpcId: vpc.id,
  tags: {
    Name: "bastion-host-sg",
  },
});

new aws.vpc.SecurityGroupIngressRule("bastion-host-sg-allow-ssh-inbound", {
  securityGroupId: bastionHostSg.id,
  description: "Allow ssh traffic from anywhere to the bastion host",
  cidrIpv4: "0.0.0.0/0",
  ipProtocol: "tcp",
  fromPort: 22,
  toPort: 22,
});

new aws.vpc.SecurityGroupEgressRule("bastion-host-sg-allo-all-outbound", {
  securityGroupId: bastionHostSg.id,
  description: "Allow all outgoing traffic from bastion host sg",
  cidrIpv4: "0.0.0.0/0",
  ipProtocol: "-1",
});

const k8sMasterNodeSg = new aws.ec2.SecurityGroup("k8s-master-node-sg", {
  name: "k8s-master-node-sg",
  description: "Security group for private k8s master nodes",
  vpcId: vpc.id,
  tags: {
    Name: "k8s-master-node-sg",
    [`kubernetes.io/cluster/${clusterName}`]: "owned",
  },
});

const k8sWorkerNodeSg = new aws.ec2.SecurityGroup("k8s-worker-node-sg", {
  name: "k8s-worker-node-sg",
  description: "Security group for private k8s worker nodes",
  vpcId: vpc.id,
  tags: {
    Name: "k8s-worker-nodes-sg",
    [`kubernetes.io/cluster/${clusterName}`]: "owned",
  },
});

new aws.vpc.SecurityGroupIngressRule(
  "k8s-master-node-sg-allow-lb-6443-inbound",
  {
    securityGroupId: k8sMasterNodeSg.id,
    description: "Allow api server traffic from private load balancer",
    ipProtocol: "tcp",
    cidrIpv4: "0.0.0.0/0",
    fromPort: 6443,
    toPort: 6443,
  },
);

new aws.vpc.SecurityGroupIngressRule(
  "k8s-master-node-sg-allow-bastion-ssh-inbound",
  {
    securityGroupId: k8sMasterNodeSg.id,
    description: "Allow bastion host ssh traffic to master node",
    referencedSecurityGroupId: bastionHostSg.id,
    ipProtocol: "tcp",
    fromPort: 22,
    toPort: 22,
  },
);

new aws.vpc.SecurityGroupIngressRule(
  "k8s-master-node-sg-allow-worker-all-inbound",
  {
    securityGroupId: k8sMasterNodeSg.id,
    referencedSecurityGroupId: k8sWorkerNodeSg.id,
    description: "Allow all traffic from worker node to master node",
    ipProtocol: "-1",
  },
);

new aws.vpc.SecurityGroupEgressRule("k8s-master-node-sg-allow-all-outbound", {
  securityGroupId: k8sMasterNodeSg.id,
  description: "Allow all outbound traffic from master node",
  ipProtocol: "-1",
  cidrIpv4: "0.0.0.0/0",
});

const trustAssumePolicyDocument = await aws.iam.getPolicyDocument({
  statements: [
    {
      actions: ["sts:AssumeRole"],
      principals: [
        {
          identifiers: ["ec2.amazonaws.com"],
          type: "Service",
        },
      ],
    },
  ],
});

const k8sMasterNodeRole = new aws.iam.Role("k8s-master-node-role", {
  name: "k8s-master-node-role",
  assumeRolePolicy: trustAssumePolicyDocument.json,
});

new aws.iam.RolePolicy("k8s-master-node-role-policy", {
  name: "k8s-master-node-policy",
  role: k8sMasterNodeRole.id,
  policy: JSON.stringify(k8sMasterNodeRolePolicyJSON),
});

const k8sWorkerNodeRole = new aws.iam.Role("k8s-worker-node-role", {
  name: "k8s-worker-node-role",
  assumeRolePolicy: trustAssumePolicyDocument.json,
});

new aws.iam.RolePolicy("k8s-worker-node-role-policy", {
  name: "k8s-worker-node-policy",
  role: k8sWorkerNodeRole.id,
  policy: JSON.stringify(k8sWorkerNodeRolePolicyJSON),
});

new aws.iam.InstanceProfile("k8s-master-node-instance-profile", {
  name: "k8s-master-node-instance-profile",
  role: k8sMasterNodeRole.name,
});

new aws.iam.InstanceProfile("k8s-worker-node-instance-profile", {
  name: "k8s-worker-node-instance-profile",
  role: k8sWorkerNodeRole.name,
});

const bastionHost = new aws.ec2.Instance("bastion-host", {
  ami: bastionHostAMI,
  instanceType: aws.ec2.InstanceType.T3_Nano,
  vpcSecurityGroupIds: [bastionHostSg.id],
  subnetId: publicSubnet01.id,
  keyName: bastionHostSSHKeyName,
  userData: bastionHostUserData,
  tags: {
    Name: "bastion-host",
  },
});

bastionHost.publicIp.apply((publicIp) =>
  console.log("Bastion Host Public IP: ", publicIp),
);

const k8sMasterNode01 = new aws.ec2.Instance("k8s-master-01", {
  ami: k8sNodeAMI,
  instanceType: aws.ec2.InstanceType.T3_Medium,
  vpcSecurityGroupIds: [k8sMasterNodeSg.id],
  subnetId: privateSubnet01.id,
  keyName: k8sSSHKeyPair.keyName,
  rootBlockDevice: {
    volumeSize: 32,
    volumeType: "gp3",
    deleteOnTermination: true,
  },
  tags: {
    Name: "k8s-master-01",
  },
});

k8sMasterNode01.privateIp.apply((privateIp) =>
  console.log("K8s Master Node 01 Private IP:", privateIp),
);

const k8sMasterNode02 = new aws.ec2.Instance("k8s-master-02", {
  ami: k8sNodeAMI,
  instanceType: aws.ec2.InstanceType.T3_Medium,
  vpcSecurityGroupIds: [k8sMasterNodeSg.id],
  subnetId: privateSubnet02.id,
  keyName: k8sSSHKeyPair.keyName,
  rootBlockDevice: {
    volumeSize: 32,
    volumeType: "gp3",
    deleteOnTermination: true,
  },
  tags: {
    Name: "k8s-master-02",
  },
});

k8sMasterNode02.privateIp.apply((privateIp) =>
  console.log("K8s Master Node 02 Private IP:", privateIp),
);

const k8sMasterTg = new aws.lb.TargetGroup("k8s-master-tg", {
  name: "k8s-master-tg",
  port: 6443,
  protocol: "TCP",
  targetType: "ip",
  vpcId: vpc.id,
  ipAddressType: "ipv4",
});

[k8sMasterNode01, k8sMasterNode02].map((node, i) => {
  new aws.lb.TargetGroupAttachment(`k8s-master-tg-${i}-attachment`, {
    port: 6443,
    targetId: node.privateIp,
    targetGroupArn: k8sMasterTg.arn,
  });
});

const k8sApiServerLb = new aws.lb.LoadBalancer("k8s-api-server-lb", {
  name: "k8s-api-server-lb",
  internal: true,
  loadBalancerType: "network",
  securityGroups: [k8sApiServerLbSg.id],
  subnets: [privateSubnet01.id, privateSubnet02.id],
  tags: {
    Name: "k8s-api-server-lb",
    [`kubernetes.io/cluster/${clusterName}`]: "owned",
  },
});

new aws.lb.Listener("k8s-api-server-listener", {
  loadBalancerArn: k8sApiServerLb.arn,
  port: 6443,
  protocol: "TCP",
  defaultActions: [
    {
      type: "forward",
      targetGroupArn: k8sMasterTg.arn,
    },
  ],
});
