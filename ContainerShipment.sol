// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Registration{

    //participating stakeholders
    struct Stakeholder{
        //string stakeholderRole;      
        uint256 ID;
    }
    mapping(address => Stakeholder) stakeholders;

    event StakeholderRegistered(string info);
   
    function register( address roleAddress, uint256 roleID) public{
        //stakeholders[roleAddress].stakeholderRole = role;
        stakeholders[roleAddress].ID = roleID;
        emit StakeholderRegistered("Stakeholder registered.");
    }   
}

//import "@openzeppelin/contracts/utils/Counters.sol";

/*
    ID assignment: 
    1 - For exporter and Importer
    2 - Freight forwarders
    3 - Inland Carriers
    4 - Sea Carrier
    5 - Air Carrier
    6 - Authorities, for customs agents
*/

contract ContainerShipment { 
    address constant exporter= 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    address constant importer=0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; 
    address constant freightfrw=0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
    address constant agent=0x17F6AD8Ef982297579C203069C1DbfFE4348c372;
    address constant truck= 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;
    address constant sea=0x617F2E2fD72FD9D5503197092aC168c91465E7f2;
    constructor (){
        //exporter = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        //importer = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // or receiver
        //freightfrw = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
    }

    // using Counters for Counters.Counter;
    //Counters.Counter private counter;
    //uint256 ID_counter;

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

    //mapping(bytes32 => bytes32) IPFShash;

    struct Containers{
        //uint256 ID;
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
    //mapping(uint256 => Container) containers;
    Containers container;

    //Tracking events
    event ShipmentRequested(address addr);
    event StakeholderRegistered(string str, string info);
    event RequiredDocumentsVerified(string str, address addr);
    event ContainerShipmentCreated(string str, bool mode);
    event BillofLadingIssued(string str);
    event CustomsClearanceApproved(string s, string str);

    event RequestForInlandCarrier(string str);
    event RequestForSeaCarrier(string str);

    event ContainerLoadedToInlandCarrier();
    event ContainerLoadedToSeaCarrier();
    event ContainerLoadedToAirCarrier();

    event ContainerHandoffRequested(uint256 nCarrierID, string loc);

    event TranshipmentPermitRequested();
    event TranshipmentPermitIssued(string str);
    event ShipmentReachedDestinationSuccessfully();
    event ErrorBroadcast(string str);
    
    
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
        require(msg.sender == agent); //  ID = 6 for authorities
        _;
    }
    modifier onlyAgents{   // only freight forwarder and custom agents 
        require(msg.sender == freightfrw || msg.sender == agent); 
        _;
    }
    modifier onlyTransporters{  // transporters and freight forwarders
                                require(msg.sender == truck || // Inland Carriers
                                msg.sender == sea || // Sea Carriers
                                //stakeholders[msg.sender].ID == 5 ||
                                msg.sender == freightfrw); // Air Carriers
        _;
    }
    
    // ################# getter function for container ID!!!!!!!!!!!!!!
    function readContainerState() public view returns(ContainerState){
        return container.cState;
    }
    
    // Placing the shipment order by the exporter only    
    function requestShipment(string memory c_origin, string memory c_destination, string memory c_size, 
    string memory c_content, address receiverAddr) public onlyExporter {    
        //ID_counter = counter.current();
        
        container.originPlace = bytes32(bytes(c_origin));
        container.destinationPlace = bytes32(bytes(c_destination));
        container.content = bytes32(bytes(c_content));
        container.size = bytes32(bytes(c_size));
        container.receiver = receiverAddr;

        container.cState = ContainerState.Requested;     
        emit ShipmentRequested(msg.sender);  
        //counter.increment();  
    }
    
    function documentsVerification() public onlyAgents{ 
        if (msg.sender == freightfrw){  // The freight forwarder verfies documents prior to the shipment departure
            require(container.cState == ContainerState.Requested, "Shipment request not submitted!");

            // Documents required are packaging list, commercial invoice and certificate of origin
            // The documents are checked in person in the container sealing and stuffing stage

            container.cState = ContainerState.Ready;
            //container.ID = containerID;
            emit RequiredDocumentsVerified("Required documents for shipment verfied by: ", msg.sender);    
        }

        else { // This is the authorities
        
            if((container.cState == ContainerState.ExportCustomsClearanceReq) ||
               (container.transportMode.multimodal == false)){
                container.cState = ContainerState.ExportCustomsCDocumentsApprv;
                emit RequiredDocumentsVerified("Required documents for export clearance verified by: ", msg.sender);
            }
            else if(container.cState == ContainerState.ImportCustomsClearanceReq ||
                    container.transportMode.multimodal == false) {
                container.cState = ContainerState.ImportCustomsCDocumentsApprv;
                emit RequiredDocumentsVerified("Required documents for import clearance verified by: ", msg.sender);
            }   
            else if(container.cState == ContainerState.TransshipmentPermitReq) {
                container.cState = ContainerState.TransshipmentDocsApproved;
                emit RequiredDocumentsVerified("Transshipment documents verified by: ", msg.sender);
            }              
        }
        //emit RequiredDocumentsVerified("Required documents", str, " verified by: ", msg.sender); how about this ?
    }

    //unimodal shipment
    function createUnimodalShipment(uint256 HaulTruck) public onlyFreightFrw {

        require(container.cState == ContainerState.Ready, "Documents not verified!");
        container.transportMode.multimodal = false;
        container.transportMode.exportHaulageC = HaulTruck;
        container.cState = ContainerState.ShipmentCreated;
        emit ContainerShipmentCreated("Shipment Ready for first-mile haulage, Multimodal = ", false);            
    }

    // multimodal shipment
    function createMultimodalShipment(string memory port_origin, string memory port_destination, 
                                      uint256 exportHaulCount, bool isTransshiped, 
                                      uint256 vesselsCount, uint256 importHaulCount) public onlyFreightFrw {

        require(container.cState == ContainerState.Ready && vesselsCount != 0, 
                "please check shipment request and/or details properly");
        
        container.originPort = bytes32(bytes(port_origin));
        container.destinationPort = bytes32(bytes(port_destination));
        container.transportMode.multimodal = true;
        container.transportMode.exportHaulageC = exportHaulCount;
        container.transportMode.transhipContainer = isTransshiped;
        container.transportMode.vessels = vesselsCount;   
        container.transportMode.importHaulageC = importHaulCount;     
        
        if(isTransshiped) { // If transshipped, the minimum number of vessels is 2
            require(vesselsCount > 1, "please check shipment details properly");
            container.transportMode.numOfTranshipments = vesselsCount - 1; 
            }
        else { 
            require(vesselsCount == 1, "please check shipment details properly");
            container.transportMode.numOfTranshipments = 0; 
            }
            container.cState = ContainerState.ShipmentCreated;
            emit ContainerShipmentCreated("Shipment Ready for first-mile haulage, Multimodal = ", true);            
    }
   
    function issueBoL(string memory hashIPFS) public onlyFreightFrw{
        require(container.cState == ContainerState.ShipmentCreated, "Please create shipment first");

        setIPFSLink("Bill of Lading", hashIPFS); 
        container.cState = ContainerState.BoLIssued;
        emit BillofLadingIssued("Bill of Lading issued and stored in Database."); 

        inlandCarrierRequest(); //check if this is being called 
    }
    
    // The issuer of a document stores the document in ipfs with its hash link stored in blockchain 
    function setIPFSLink(string memory documentName, string memory hashLink) public{
        //######################## check the link 
        container.IPFShash[bytes32(bytes(documentName))] = hashLink;       
    }
    function getIPFSLink( string memory documentName) public view returns (string memory){
        return container.IPFShash[bytes32(bytes(documentName))];
    }

    // Request for inland transport, for highway, railway  and/or airway
    function inlandCarrierRequest() private{
        require(container.transportMode.exportHaulageC > 0 || container.transportMode.importHaulageC > 0, "Invalid inland carrier request");
        if (container.transportMode.exportHaulageC > 0){  // export haulage
            container.transportMode.exportHaulageC = container.transportMode.exportHaulageC - 1;
            emit RequestForInlandCarrier("Export InLand carrier requested");
                 
        }
        else{   // carrier request in import inland haulage            
            require(container.transportMode.vessels == 0, "Invalid request");
            container.transportMode.importHaulageC = container.transportMode.importHaulageC - 1;
            emit RequestForInlandCarrier("Import InLand carrier requested");
        }
        container.cState = ContainerState.CarrierRequested;
    }

    function seaCarrierRequest() private{
        require((container.transportMode.vessels > 0) &&
                (container.cState == ContainerState.CarrierRequested),"Invalid vessel request");
        
        container.transportMode.vessels = container.transportMode.vessels - 1;
        container.cState = ContainerState.CarrierRequested;
        emit RequestForSeaCarrier("Sea carrier requested");           
    }

    function containerHandoff(uint256 nextCarrierID, string memory location) public onlyTransporters{ // check the sequence diagram
        require(container.cState == ContainerState.InlandCarrierApproved || 
                container.cState == ContainerState.SeaCarrierApproved || 
                container.cState == ContainerState.AirCarrierApproved, "Invalid step");        
        
        //container.cState = ContainerState.CarrierRequested;
        emit ContainerHandoffRequested(nextCarrierID, location);

        if(msg.sender == truck){
            if(nextCarrierID == 3){  // Inland cargo transfer
                require(container.transportMode.exportHaulageC > 0, "Invalid step");
                inlandCarrierRequest();
            }
            else if(nextCarrierID == 4){  // Container reached origin port
                // call exportcustomsclearance
                require(container.transportMode.exportHaulageC == 0 && 
                        container.transportMode.vessels > 0, "Invalid step");
                container.cState = ContainerState.ExportCustomsClearanceReq;
                //seaCarrierRequest(container.ID);
            }           
        } 
        else if(msg.sender == sea){
            if(nextCarrierID == 3){   // Container reached destination port
                // call importcustomsclearance
                require(container.transportMode.vessels == 0 &&
                        container.transportMode.importHaulageC > 0, "Invalid step");
                container.cState = ContainerState.ImportCustomsClearanceReq;
                //inlandCarrierRequest(container.ID);
            }
            else if(nextCarrierID == 4){ // Ocean transshipment
                // decrement transshipment here, 
                // call transhipment permit
                require(container.transportMode.numOfTranshipments > 0, "Invalid step");
                container.transportMode.numOfTranshipments = container.transportMode.numOfTranshipments - 1;
                container.cState = ContainerState.TransshipmentPermitReq;
                emit TranshipmentPermitRequested();
                //seaCarrierRequest(container.ID); //check
            }
        } 
        
    }    
   
    function approveCarrierRequest() public onlyTransporters{

        // Check ID to differentiate between the transportation type
    require(container.cState == ContainerState.CarrierRequested, "Invalid step");  
        
        if(msg.sender == truck){
            container.cState = ContainerState.InlandCarrierApproved;     
            emit ContainerLoadedToInlandCarrier();
        }

        else if(msg.sender == sea){
            container.cState = ContainerState.SeaCarrierApproved;     
            emit ContainerLoadedToSeaCarrier(); 
        }

        //else if(stakeholders[msg.sender].ID == 5){
        //    container.cState = ContainerState.AirCarrierApproved;  
        //    emit ContainerLoadedToAirCarrier(container.ID); 
        //}

        else { emit ErrorBroadcast("Unknown Request"); }
    }

    function customsClearance( string memory hashIPFS) public onlyCustomAgents{
        require(container.cState == ContainerState.ExportCustomsCDocumentsApprv || 
                container.cState == ContainerState.ImportCustomsCDocumentsApprv, "Unidentified request");
        string memory customsType;
        //container.cState = ContainerState.CarrierRequested;
        if(container.cState == ContainerState.ExportCustomsCDocumentsApprv){
            customsType = "Export CustomsC";
            container.cState = ContainerState.CarrierRequested;
            seaCarrierRequest();
            //setIPFSLink(containerID, "Export CustomsC", hashIPFS);
        }
        else{
            customsType = "Import CustomsC";
            container.cState = ContainerState.CarrierRequested;
            inlandCarrierRequest();
            //setIPFSLink(containerID, "Import CustomsC", hashIPFS);
        }
        setIPFSLink(customsType, hashIPFS);   
        emit CustomsClearanceApproved(customsType, " issued and stored in Database."); 
    }
     
    function transhipmentPermit(string memory hashIPFS) public onlyAgents{
        require(container.cState == ContainerState.TransshipmentDocsApproved, "Unidentified request");
        container.cState = ContainerState.CarrierRequested;
        seaCarrierRequest();
        setIPFSLink("Transshipment permit", hashIPFS);
        emit TranshipmentPermitIssued("Transhipment permit issued and stored in Database.");
    }
  
    function shipmentArrivedDestinationSignal() public onlyImporter{
        container.cState = ContainerState.Destination; 
        emit ShipmentReachedDestinationSuccessfully();
    }
}

// receiver, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
// truck, 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB, 3
// sea, 0x617F2E2fD72FD9D5503197092aC168c91465E7f2, 4
// agent, 0x17F6AD8Ef982297579C203069C1DbfFE4348c372, 6
//hash QmPK1s3pNYLi9ERiq3BDxKa4XosgWwFRQUydHUtz4YgpqB
