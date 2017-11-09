pragma solidity ^0.4.16;

contract token { mapping(address=>uint256) public balanceOf; }

contract admined {
 address public admin;

 function admined() public {
    admin = msg.sender;
 }

 modifier onlyAdmin(){
    require(msg.sender == admin) ;
    _;
 }

 function transferAdminship(address newAdmin) onlyAdmin public {
    admin = newAdmin;
 }

}

contract Association is admined {

    uint public minimumQuorum;
    uint public debatingPeriodInMinutes;
    
    Proposal[] public proposals;
    uint public numProposals;

    
    token public sharesTokenAddress;

    modifier onlyShareholders {
        require(sharesTokenAddress.balanceOf(msg.sender) != 0) ;
        _;
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
        address voter;
    }

    /* First time setup */
    function Association(
        address sharesAddress,
        uint minimumSharesToPassAVote,
        uint minutesForDebate,
        address leader) payable public {
        changeVotingRules(sharesAddress, minimumSharesToPassAVote, minutesForDebate);
        if(leader == 0) admin = msg.sender;
        else admin = leader;

    }

    /*change rules*/
    function changeVotingRules(
        address sharesAddress,
        uint minimumSharesToPassAVote,
        uint minutesForDebate) onlyAdmin public {
        sharesTokenAddress = token(sharesAddress);
        if(minimumSharesToPassAVote == 0) minimumSharesToPassAVote = 1;
        minimumQuorum = minimumSharesToPassAVote;
        debatingPeriodInMinutes = minutesForDebate;

    }

    /* Function to create a new proposal */
    function newProposal(
        address beneficiary,
        uint etherAmount,
        string jobDescription,
        bytes transactionBytecode) onlyShareholders public returns (uint proposalID){

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
        bool supportsProposal) onlyShareholders public returns (uint voteID){
        Proposal storage p = proposals[proposalNumber];
        if(p.voted[msg.sender]) return;
        p.voted[msg.sender] = true;
        voteID = p.votes.length++;
        p.votes[voteID] = Vote({inSupport: supportsProposal, voter: msg.sender});
        p.numberOfVotes++;
        return voteID;
    }

    function executeProposal(uint proposalNumber, bytes transactionBytecode) public {
        
     Proposal storage p = proposals[proposalNumber];
      
      if(now < p.votingDeadline || 
        p.executed ||
        p.proposalHash != keccak256(p.recipient, p.amount, transactionBytecode)
        )
      return;

      uint quorum = 0;
      uint yea = 0;
      uint nay = 0;

      for(uint i=0; i< p.votes.length; i++){
        Vote storage v = p.votes[i];
        uint voteWeight = sharesTokenAddress.balanceOf(v.voter);
        quorum +=voteWeight;
        if(v.inSupport){
            yea += voteWeight;
        }
        else{
            nay += voteWeight;
        }
      }

      if(quorum <= minimumQuorum){
        return;
      }
      else if(yea > nay){
        p.executed = true;
        if(!p.recipient.call.value(p.amount * 1 ether)(transactionBytecode)){
            revert();
        }
        p.proposalPassed = true;
      }
      else{
        p.proposalPassed = false;
      }
    }

    function () payable public {
    }


}