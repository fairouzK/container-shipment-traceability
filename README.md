# container-shipment-traceability
Published paper: Blockchain-based Traceability for Shipping Containers in Unimodal and Multimodal Logistics <br>
IEEE link: https://ieeexplore.ieee.org/abstract/document/9997538

### Abstract
An unprecedented amount of goods and commodities are shipped and transported globally each day through different modes of transport. Due to its complexity, the maritime industry suffers from a lack of trust and secure ownership evidence, protracted documentation procedures, and excessive data aggregation. These shortcomings are reflected in cargo processing delays and elevated costs in the shipping process. Most of today’s systems and technologies leveraged for managing shipping containers in unimodal and multimodal logistics fall short of providing transparency, traceability, reliability, audit, security, and trust features. In this paper, we propose a blockchain-based solution that allows users to trace and track their container shipments in a manner that is decentralized, transparent, auditable, secure, and trustworthy. We employ the InterPlanetary File System (IPFS) to overcome the limited data storage problem. We develop smart contracts and present algorithms along with their full implementation, testing, and validation details in both unimodal and multimodal logistics. We present security and cost analyses to show that the proposed solution is secure and cost-efficient. Furthermore, we compare our proposed solution with the existing solutions to show its novelty. All developed smart contract codes are made publicly available on GitHub.

### About Code Implementation
There are two versions of this code.

1. containerShipment.sol - Main implementation [used in the paper]  
Uses a separate smart contract for every container, i.e every container is recognized by the smart contract address.

2. container_shipment - Updated   
A smart contract deployed once. It contains counters to distinguish between the containers.
Shipments are recognized by the counter number and the ethereum address of the shipper.

The freight forwarder registers the participating actors.


### Process flow
0. The participants are registered and assigned roles through the register() function.
1. Shipper places a shipment request using requestShipment() function.
2. Shipping agent approves the required documents through the documentsVerification() function.
3. The shipping agent sets the details of the shipping process such as required land haulage, ocean haulage, transshipments(is required) and creates either a unimodal or multimodal shipment using either createUnimodalShipment() or createMultimodalShipment() functions.
4. The bill of lading is issued, uploaded to IPFS and its CID broadcast using the function issueBoL().
5. During the haulage, both land and ocean, the container handover is broadcast using the containerHandoff() function, and the respective transporter approves the handover using the approveCarrierRequest() function.
6.The customs office approve documents for export and import using documentsVerification() function.
7. Upon reaching the destination, the last transporter confirms the process using shipmentArrivedDestinationSignal() function.
