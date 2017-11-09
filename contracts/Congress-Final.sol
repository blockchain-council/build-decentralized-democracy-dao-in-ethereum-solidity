pragma solidity ^0.4.16;

contract admined {
 address public admin;

 function admined() public {
    admin = msg.sender;
 }

 modifier onlyAdmin(){
    require(msg.sender == admin) ;
    _;
 }

 function transferAdminship(address newAdmin) onlyAdmin public{
    admin = newAdmin;
 }

}

contract Congress is admined {

    uint public minimumQuorum;
    uint public debatingPeriodInMinutes;
    int public majorityMargin;
    Proposal[] public proposals;
    uint public numProposals;
    mapping (address => uint) public memberId;
    Member[] public members;

    modifier onlyMembers {
        require(memberId[msg.sender] != 0) ;
        _;
    }

    struct Member{
        address member;
        string name;
        uint memberSince;
    }

    struct Proposal {
        address recipient;
        uint amount;
        string description;
        uint votingDeadline;
        bool executed;
        bool proposalPassed;
        uint numberOfVotes;
        int currentResult;
        bytes32 proposalHash;
        Vote[] votes;
        mapping (address => bool) voted;
    }

    struct Vote {
        bool inSupport;
        string name;
        uint memberSince;
    }

    /* First time setup */
    function Congress(
        uint minimumQuorumForProposal,
        uint minutesForDebate,
        int marginOfVotesForMajority,
        address congressLeader) payable public {
        changeVotingRules(minimumQuorumForProposal,minutesForDebate, marginOfVotesForMajority);
        if(congressLeader == 0) admin = msg.sender;
        else admin = congressLeader;

        addMember(0,"");
        addMember(admin,"Admin");

    }

    /*make member*/
    function addMember(address targetMember, string memberName) onlyAdmin public {
        uint id;
        if(memberId[targetMember] == 0){
            memberId[targetMember] = members.length; // 5, 
            id = members.length;
            members.length = members.length + 1;
            members[id] = Member({member: targetMember, memberSince: now, name: memberName});
        }
        else{
            id = memberId[targetMember];
            //Member storage m = members[id];
        }

    }

    function removeMember(address targetMember) onlyAdmin public {
        require(memberId[targetMember] != 0) ;
        for(uint i = memberId[targetMember]; i < members.length-1; i++){
            members[i] = members[i+1];
        }
        delete members[members.length-1];
        members.length--;
    }

    /*change rules*/
    function changeVotingRules(
        uint minimumQuorumForProposal,
        uint minutesForDebate,
        int marginOfVotesForMajority) onlyAdmin public {
        minimumQuorum = minimumQuorumForProposal;
        debatingPeriodInMinutes = minutesForDebate;
        majorityMargin = marginOfVotesForMajority;

    }

    /* Function to create a new proposal */
    function newProposal(
        address beneficiary,
        uint etherAmount,
        string jobDescription,
        bytes transactionBytecode) onlyMembers public returns (uint proposalID){

        proposalID = proposals.length;
        proposals.length = proposals.length + 1;
        Proposal storage p = proposals[proposalID];
        p.recipient = beneficiary;
        p.amount = etherAmount;
        p.description = jobDescription;
        p.proposalHash = keccak256(beneficiary, etherAmount, transactionBytecode);
        p.votingDeadline = now + (debatingPeriodInMinutes * 1 minutes);
        p.executed = false;
        p.proposalPassed = false;
        p.numberOfVotes = 0;
        numProposals = proposalID+1;
    
        return proposalID;
    }

    /* function to check if a proposal code matches */
    function checkProposalCode(
        uint proposalNumber, 
        address beneficiary, 
        uint etherAmount, 
        bytes transactionBytecode) constant public returns (bool codeChecksOut){
        Proposal storage p = proposals[proposalNumber];
        return p.proposalHash == keccak256(beneficiary, etherAmount, transactionBytecode);
    }

    function vote(
        uint proposalNumber,
        bool supportsProposal
        ) onlyMembers public returns (uint voteID){
    
    Proposal storage p = proposals[proposalNumber];
        if(p.voted[msg.sender]) return;
        p.voted[msg.sender] = true;
        p.numberOfVotes++;
        if(supportsProposal){
            p.currentResult++;
        }
        else{
            p.currentResult--;
        }

        return p.numberOfVotes;

    }

    function executeProposal(uint proposalNumber, bytes transactionBytecode) public {
        
     Proposal storage p = proposals[proposalNumber];
      
      if(now < p.votingDeadline || 
        p.executed ||
        p.proposalHash != keccak256(p.recipient, p.amount, transactionBytecode) ||
        p.numberOfVotes < minimumQuorum)
      return;

      if(p.currentResult > majorityMargin){
        p.executed = true;
        if(!p.recipient.call.value(p.amount * 1 ether)(transactionBytecode)){
            return;
        }
        p.proposalPassed = true;
      }
      else{
        p.proposalPassed = true;
      }



    }

    function () payable public {
    }


}