// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";

/*
    ID assignment: 
    1 - For exporter and Importer
    2 - Freight forwarders
    3 - Inland Carriers
    4 - Sea Carrier
    5 - Air Carrier
    6 - Authorities, for customs agents
*/

contract ShipmentContainer { 
    address exporter;
    address importer; 
    address freightfrw; //freight forwarder

    using Counters for Counters.Counter;
    Counters.Counter private counter;
    uint256 ID_counter;

    enum ContainerState { 
        None, Requested, Ready, BoLIssued, ShipmentCreated, CarrierRequested,  //5 
        InlandCarrierApproved, SeaCarrierApproved, AirCarrierApproved,   //8
        ExportCustomsClearanceReq, ExportCustomsCDocumentsApprv, //10
        TransshipmentPermitReq, TransshipmentDocsApproved, //12
        ImportCustomsClearanceReq, ImportCustomsCDocumentsApprv, //14
        Destination
    }

    struct TransportM {  
        bool multimodal;
        uint256 exportHaulageC;
        bool transhipContainer;
        uint256 numOfTranshipments;
        uint256 vessels;
        uint256 importHaulageC;
        //uint256 airC;
        //uint256 railC;
    }

    mapping(bytes32 => bytes32) IPFShash;

    struct Container{
        uint256 ID;
        bytes32 originPlace;
        bytes32 destinationPlace;
        bytes32 content;
        bytes32 size;
        address receiver;
        bytes32 originPort;
        bytes32 destinationPort;
        ContainerState cState;      // state of the container    
        mapping(bytes32 => string) IPFShash;
        TransportM transportMode; 
    } 
    mapping(uint256 => Container) containers;

    //participating stakeholders
    struct Stakeholder{
        bytes32 stakeholderRole;      
        uint256 ID;
    }
    mapping(address => Stakeholder) stakeholders;

    //Tracking events
    event ShipmentRequested(address addr, uint256 id);
    event StakeholderRegistered(string str, string info);
    event RequiredDocumentsVerified(string str, address addr);
    event ContainerShipmentCreated(string str, uint256 id, string str2, bool mode);
    event BillofLadingIssued(string str, uint256 id);
    event CustomsClearanceApproved(string s, string str, uint256 id);

    event RequestForInlandCarrier(string str, uint256 id);
    event RequestForSeaCarrier(string str, uint256 id);

    event ContainerLoadedToInlandCarrier(uint256 id);
    event ContainerLoadedToSeaCarrier(uint256 id);
    event ContainerLoadedToAirCarrier(uint256 id);

    event ContainerHandoffRequested(uint256 id, uint256 nCarrierID, string loc);

    event TranshipmentPermitRequested(uint256 id);
    event TranshipmentPermitIssued(string str, uint256 id);
    event ShipmentReachedDestinationSuccessfully();
    event ErrorBroadcast(string str);
    
    constructor (){
        exporter = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        importer = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // or receiver
        freightfrw = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
    }

    //modifiers
    modifier onlyExporter {  //what if any of the others want to be exporters
        require(msg.sender == exporter);
        _;
    }  
    modifier onlyFreightFrw { 
        require(msg.sender == freightfrw);
        _;
    }
    modifier onlyImporter{
        require(msg.sender == importer);
        _;
    }
    modifier onlyCustomAgents{
        require(stakeholders[msg.sender].ID == 6); //  ID = 6 for authorities
        _;
    }
    modifier onlyAgents{   // only freight forwarder and custom agents 
        require(msg.sender == freightfrw || stakeholders[msg.sender].ID == 6); 
        _;
    }
    modifier onlyTransporters{  // transporters and freight forwarders
                                require(stakeholders[msg.sender].ID == 3 || // Inland Carriers
                                stakeholders[msg.sender].ID == 4 || // Sea Carriers
                                //stakeholders[msg.sender].ID == 5 ||
                                msg.sender == freightfrw); // Air Carriers
        _;
    }
    modifier onlyInlandCarrier{
        require(stakeholders[msg.sender].ID == 3); 
        _;
    }
    modifier onlySeaCarrier{
        require(stakeholders[msg.sender].ID == 4); 
        _;
    }
    modifier onlyAirCarrier{
        require(stakeholders[msg.sender].ID == 5); 
        _;
    }

    // ################# getter function for container ID!!!!!!!!!!!!!!

    function readContainerState(uint256 containerID) public view returns(ContainerState){
        return containers[containerID].cState;
    }

    // This will probably be a separate sc, and will have to check lisence ??????
    //register the participating stakeholders, only the freight forwarder can.
    function register(string memory role, address roleAddress, uint256 roleID) public onlyFreightFrw{
        stakeholders[roleAddress].stakeholderRole = bytes32(bytes(role));
        stakeholders[roleAddress].ID = roleID;
        emit StakeholderRegistered(role, " registered.");
    }
    
    // Placing the shipment order by the exporter only    
    function requestShipment(string memory c_origin, string memory c_destination, string memory c_size, 
    string memory c_content, address receiverAddr) public onlyExporter {    
        ID_counter = counter.current();
        
        containers[ID_counter].originPlace = bytes32(bytes(c_origin));
        containers[ID_counter].destinationPlace = bytes32(bytes(c_destination));
        containers[ID_counter].content = bytes32(bytes(c_content));
        containers[ID_counter].size = bytes32(bytes(c_size));
        containers[ID_counter].receiver = receiverAddr;

        containers[ID_counter].cState = ContainerState.Requested;     
        emit ShipmentRequested(msg.sender, ID_counter);  
        counter.increment();  
    }
    
    function documentsVerification(uint256 containerID) public onlyAgents{ 
        if (msg.sender == freightfrw){  // The freight forwarder verfies documents prior to the shipment departure
            require(containers[containerID].cState == ContainerState.Requested, "Shipment request not submitted!");

            // Documents required are packaging list, commercial invoice and certificate of origin
            // The documents are checked in person in the container sealing and stuffing stage

            containers[containerID].cState = ContainerState.Ready;
            containers[containerID].ID = containerID;
            emit RequiredDocumentsVerified("Required documents for shipment verfied by: ", msg.sender);    
        }

        else { // This is the authorities
        
            if((containers[containerID].cState == ContainerState.ExportCustomsClearanceReq) ||
               (containers[containerID].transportMode.multimodal == false)){
                containers[containerID].cState = ContainerState.ExportCustomsCDocumentsApprv;
                emit RequiredDocumentsVerified("Required documents for export clearance verified by: ", msg.sender);
            }
            else if(containers[containerID].cState == ContainerState.ImportCustomsClearanceReq ||
                    containers[containerID].transportMode.multimodal == false) {
                containers[containerID].cState = ContainerState.ImportCustomsCDocumentsApprv;
                emit RequiredDocumentsVerified("Required documents for import clearance verified by: ", msg.sender);
            }   
            else if(containers[containerID].cState == ContainerState.TransshipmentPermitReq) {
                containers[containerID].cState = ContainerState.TransshipmentDocsApproved;
                emit RequiredDocumentsVerified("Transshipment documents verified by: ", msg.sender);
            }              
        }
        //emit RequiredDocumentsVerified("Required documents", str, " verified by: ", msg.sender); how about this ?
    }

    //unimodal shipment
    function createUnimodalShipment(uint256 containerID, uint256 HaulTruck) public onlyFreightFrw {

        require(containers[containerID].cState == ContainerState.Ready, "Documents not verified!");
        containers[containerID].transportMode.multimodal = false;
        containers[containerID].transportMode.exportHaulageC = HaulTruck;
        containers[containerID].cState = ContainerState.ShipmentCreated;
        emit ContainerShipmentCreated("Shipment Ready for first-mile haulage with ID = ", containers[containerID].ID, "Multimodal = ", false);            
    }

    // multimodal shipment
    function createMultimodalShipment(uint256 containerID, string memory port_origin, string memory port_destination, 
                                      uint256 exportHaulCount, bool isTransshiped, 
                                      uint256 vesselsCount, uint256 importHaulCount) public onlyFreightFrw {

        require(containers[containerID].cState == ContainerState.Ready && vesselsCount != 0, 
                "please check shipment request and/or details properly");
        
        containers[containerID].originPort = bytes32(bytes(port_origin));
        containers[containerID].destinationPort = bytes32(bytes(port_destination));
        containers[containerID].transportMode.multimodal = true;
        containers[containerID].transportMode.exportHaulageC = exportHaulCount;
        containers[containerID].transportMode.transhipContainer = isTransshiped;
        containers[containerID].transportMode.vessels = vesselsCount;   
        containers[containerID].transportMode.importHaulageC = importHaulCount;     
        
        if(isTransshiped) { // If transshipped, the minimum number of vessels is 2
            require(vesselsCount > 1, "please check shipment details properly");
            containers[containerID].transportMode.numOfTranshipments = vesselsCount - 1; 
            }
        else { 
            require(vesselsCount == 1, "please check shipment details properly");
            containers[containerID].transportMode.numOfTranshipments = 0; 
            }
            containers[containerID].cState = ContainerState.ShipmentCreated;
            emit ContainerShipmentCreated("Shipment Ready for first-mile haulage with ID = ", 
                                            containers[containerID].ID, "Multimodal = ", true);            
    }
   
    function issueBoL(uint256 containerID, string memory hashIPFS) public onlyFreightFrw{
        require(containers[containerID].cState == ContainerState.ShipmentCreated, "Please create shipment first");

        setIPFSLink(containerID, "Bill of Lading", hashIPFS); 
        containers[containerID].cState = ContainerState.BoLIssued;
        emit BillofLadingIssued("Bill of Lading issued and stored in Database.", containers[containerID].ID); 

        inlandCarrierRequest(containers[containerID].ID); //check if this is being called 
    }
    
    // The issuer of a document stores the document in ipfs with its hash link stored in blockchain 
    function setIPFSLink(uint256 containerID, string memory documentName, string memory hashLink) public{
        //######################## check the link 
        containers[containerID].IPFShash[bytes32(bytes(documentName))] = hashLink;       
    }
    function getIPFSLink(uint256 containerID, string memory documentName) public view returns (string memory){
        return containers[containerID].IPFShash[bytes32(bytes(documentName))];
    }

    // Request for inland transport, for highway, railway  and/or airway
    function inlandCarrierRequest(uint256 containerID) private{
        require(containers[containerID].transportMode.exportHaulageC > 0 || containers[containerID].transportMode.importHaulageC > 0, "Invalid inland carrier request");
        if (containers[containerID].transportMode.exportHaulageC > 0){  // export haulage
            containers[containerID].transportMode.exportHaulageC = containers[containerID].transportMode.exportHaulageC - 1;
            emit RequestForInlandCarrier("Export InLand carrier requested for ", containers[containerID].ID);
                 
        }
        else{   // carrier request in import inland haulage            
            require(containers[containerID].transportMode.vessels == 0, "Invalid request");
            containers[containerID].transportMode.importHaulageC = containers[containerID].transportMode.importHaulageC - 1;
            emit RequestForInlandCarrier("Import InLand carrier requested for ", containers[containerID].ID);
        }
        containers[containerID].cState = ContainerState.CarrierRequested;
    }

    function seaCarrierRequest(uint256 containerID) private{
        require((containers[containerID].transportMode.vessels > 0) &&
                (containers[containerID].cState == ContainerState.CarrierRequested),"Invalid vessel request");
        
        containers[containerID].transportMode.vessels = containers[containerID].transportMode.vessels - 1;
        containers[containerID].cState = ContainerState.CarrierRequested;
        emit RequestForSeaCarrier("Sea carrier requested for ", containers[containerID].ID);           
    }

    function containerHandoff(uint256 containerID, uint256 nextCarrierID, string memory location) public onlyTransporters{ // check the sequence diagram
        require(containers[containerID].cState == ContainerState.InlandCarrierApproved || 
                containers[containerID].cState == ContainerState.SeaCarrierApproved || 
                containers[containerID].cState == ContainerState.AirCarrierApproved, "Invalid step");        
        
        //containers[containerID].cState = ContainerState.CarrierRequested;
        emit ContainerHandoffRequested(containerID, nextCarrierID, location);

        if(stakeholders[msg.sender].ID == 3){
            if(nextCarrierID == 3){  // Inland cargo transfer
                require(containers[containerID].transportMode.exportHaulageC > 0, "Invalid step");
                inlandCarrierRequest(containerID);
            }
            else if(nextCarrierID == 4){  // Container reached origin port
                // call exportcustomsclearance
                require(containers[containerID].transportMode.exportHaulageC == 0 && 
                        containers[containerID].transportMode.vessels > 0, "Invalid step");
                containers[containerID].cState = ContainerState.ExportCustomsClearanceReq;
                //seaCarrierRequest(containers[containerID].ID);
            }           
        } 
        else if(stakeholders[msg.sender].ID == 4){
            if(nextCarrierID == 3){   // Container reached destination port
                // call importcustomsclearance
                require(containers[containerID].transportMode.vessels == 0 &&
                        containers[containerID].transportMode.importHaulageC > 0, "Invalid step");
                containers[containerID].cState = ContainerState.ImportCustomsClearanceReq;
                //inlandCarrierRequest(containers[containerID].ID);
            }
            else if(nextCarrierID == 4){ // Ocean transshipment
                // decrement transshipment here, 
                // call transhipment permit
                require(containers[containerID].transportMode.numOfTranshipments > 0, "Invalid step");
                containers[containerID].transportMode.numOfTranshipments = containers[containerID].transportMode.numOfTranshipments - 1;
                containers[containerID].cState = ContainerState.TransshipmentPermitReq;
                emit TranshipmentPermitRequested(containers[containerID].ID);
                //seaCarrierRequest(containers[containerID].ID); //check
            }
        } 
        
    }    
   
    function approveCarrierRequest(uint256 containerID) public onlyTransporters{

        // Check ID to differentiate between the transportation type
    require(containers[containerID].cState == ContainerState.CarrierRequested, "Invalid step");  
        
        if(stakeholders[msg.sender].ID == 3){
            containers[containerID].cState = ContainerState.InlandCarrierApproved;     
            emit ContainerLoadedToInlandCarrier(containers[containerID].ID);
        }

        else if(stakeholders[msg.sender].ID == 4){
            containers[containerID].cState = ContainerState.SeaCarrierApproved;     
            emit ContainerLoadedToSeaCarrier(containers[containerID].ID); 
        }

        else if(stakeholders[msg.sender].ID == 5){
            containers[containerID].cState = ContainerState.AirCarrierApproved;  
            emit ContainerLoadedToAirCarrier(containers[containerID].ID); 
        }

        else { emit ErrorBroadcast("Unknown Request"); }
    }

    function customsClearance(uint256 containerID, string memory hashIPFS) public onlyCustomAgents{
        require(containers[containerID].cState == ContainerState.ExportCustomsCDocumentsApprv || 
                containers[containerID].cState == ContainerState.ImportCustomsCDocumentsApprv, "Unidentified request");
        string memory customsType;
        //containers[containerID].cState = ContainerState.CarrierRequested;
        if(containers[containerID].cState == ContainerState.ExportCustomsCDocumentsApprv){
            customsType = "Export CustomsC";
            containers[containerID].cState = ContainerState.CarrierRequested;
            seaCarrierRequest(containerID);
            //setIPFSLink(containerID, "Export CustomsC", hashIPFS);
        }
        else{
            customsType = "Import CustomsC";
            containers[containerID].cState = ContainerState.CarrierRequested;
            inlandCarrierRequest(containerID);
            //setIPFSLink(containerID, "Import CustomsC", hashIPFS);
        }
        setIPFSLink(containerID, customsType, hashIPFS);   
        emit CustomsClearanceApproved(customsType, " issued and stored in Database.", containers[containerID].ID); 
    }
     
    function transhipmentPermit(uint256 containerID, string memory hashIPFS) public onlyAgents{
        require(containers[containerID].cState == ContainerState.TransshipmentDocsApproved, "Unidentified request");
        containers[containerID].cState = ContainerState.CarrierRequested;
        seaCarrierRequest(containerID);
        setIPFSLink(containerID, "Transshipment permit", hashIPFS);
        emit TranshipmentPermitIssued("Transhipment permit issued and stored in Database.", containers[containerID].ID);
    }
  
    function shipmentArrivedDestinationSignal(uint256 containerID) public onlyImporter{
        containers[containerID].cState = ContainerState.Destination; 
        emit ShipmentReachedDestinationSuccessfully();
    }
}

// receiver, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
// truck, 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB, 3
// sea, 0x617F2E2fD72FD9D5503197092aC168c91465E7f2, 4
// agent, 0x17F6AD8Ef982297579C203069C1DbfFE4348c372, 6
//hash QmPK1s3pNYLi9ERiq3BDxKa4XosgWwFRQUydHUtz4YgpqB
