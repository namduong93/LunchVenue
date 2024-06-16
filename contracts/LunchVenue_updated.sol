/// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.5;

/// @title Contract to agree on the lunch venue
/// @author Dilum Bandara , CSIRO’s Data61
/// Edited by: Van Nam Duong, UNSW (z5412692) to fix the following issues
///
/// @dev Issue known:
/// 1. A friend can vote more than once. While this was handy in testing our contract, it is undesirable as one could monopolise the selected venue.
///    Ideally, we should record a vote for a given address only once.
///    - doVote function now checks if friends[msg.sender] == false to allow voting
///
/// 2. The same restaurant and friend can be added multiple times leading to similar issues.
///    - Go through list of restaurants that are currently open and determine if the restaurant already exists
///    - Go through list of friends that are currently open and determine if the friend already exists
///
/// 3. While the contract is stuck at the doVote function, other functions can still be called. Also, once the voting starts, new venues and friends
///    can be added, making the whole process chaotic. In a typical voting process, voters are clear about who would vote and what to vote on before
///    voting starts to prevent any disputes. Hence, a good vote process should have well-defined create, vote open, and vote close phases.
///    - Created a state enum variable to record the contract's current status (Creating, Voting, Closed).
///    - Added modifiers to limit the states in which functions can be called
///
/// 4. There is no way to disable the contract once it is deployed. Even the manager cannot do anything to stop the contract in case the team lunch
///    has to be cancelled.
///    - Added `Cancelled State` to keep track the state has been cancelled 
///    - Added `cancelVote` function to allow the manager to cancel the contract
///
/// 5. Gas consumption is not optimised. More simple data structures may help to reduce transaction fees.
///    - Added `unchecked` for incrementing variable i in for loops
///    - Removed initialisation of variable of 0 as public global variable are 0, or empty string
///    - Immutable (constant) type for manager variable since it will not be modified after contract construction
///    - Rearranged the order of state variables, state variable and address variable are placed together to use one slot.
///
/// 6. Bonus: Unit Test do not cover all possible cases, e.g., we do not check the doVote function with an invalid restaurant number
///    - Fixed in Testing
///
/// To show the bugs are fixed
/// Address: https://sepolia.etherscan.io/address/0xb107c50e3e771a2b2200591262f0759c9a93d8bc
/// Manager: 0x14F35082e87F9c09797443A1E591C26fA5784aDc
/// Alice: 0x9e0E6C08B59942207137A731bB64ECd124565697
/// Bob: 0x7cad0Db1199CEC9a688a520565c9ccc577A2D71b
/// 
/// Bug 1:
/// - Bob vote but fail because he is not a friend
///   https://sepolia.etherscan.io/tx/0x9176ab6c7a76edd140868106db5331e5433b9213132ec8010afefabf78d75f7c
///
/// Bug 2:
/// - Add Alice:
///   https://sepolia.etherscan.io/tx/0xa3c45b7c32a80444f46556bd6329e196e8f7ce2be81e41da883a5f3e10b082e6
/// - Add Alice again but fail with "Friend address already exists"
///   https://sepolia.etherscan.io/tx/0x10776fd15607935f1db6dfd4eee78daf8eb9e96c4be6905348af229737ac3d0f
///
/// Bug 3:
/// - Alice tried to vote in the Creating State but failed.
///   https://sepolia.etherscan.io/tx/0xce09ef8eef423c713fc90ea3f8bff1721e7abd334e21a70db3fa98d5a7b18e7b
/// - Manager then open Voting State
///   https://sepolia.etherscan.io/tx/0xb4807101db1e69ab09b9a4dfe1e9cbab83b40eaca5fd55a0e7c5fdb4564dbd2b
/// - Alice try to vote again and success:
///.  https://sepolia.etherscan.io/tx/0x57633c13be1e8d0f5be52f7296b1580cf340e154471d821882780be1946f0003
///
/// Bug 4:
/// - Alice can not cancel Voting as a friend but not a manager.
///   https://sepolia.etherscan.io/tx/0xa262a4f725c2e728d89c000f6a38028fabeb56ed975492870adce4bb08c43dbe
/// - Only Manager can cancel voting
///   https://sepolia.etherscan.io/tx/0x7bf8102e477ae3cf4183d00a996aa9d35743a030f579adeada64249cc2a038ea
///
/// Bug 5: 
/// - Gas reduce from 40000 - 60000 in LunchVenue.sol to 26000 average in LunchVenue_updated.sol
///
/// Bug 6:
/// Can not vote invalid number ( can not vote restaurant with id 10 but only have 2 restaurants)

contract LunchVenueUpdated {

    
    struct Friend {
        string name;
        bool voted; //Vote state
    }

    struct Vote {
        address voterAddress;
        uint restaurant;
    }

    //ISSUE_3: Adding states to make sure the vote is on precess
    enum State {
        Creating,
        Voting,
        Closed,
        //ISSUE_4: Adding Cancelled state so that manager can cancel one contract is deployed
        Cancelled
    }

    //ISSUE_5: Every initial global variable will be 0 without setting
    mapping (uint => string) public restaurants; //List of restaurants (restaurant no, name)
    mapping (address => Friend) public friends; //List of friends (address, Friend)
    uint public numRestaurants;
    uint public numFriends;
    uint public numVotes;
    //ISSUE_5: manager will be constant variable
    address public immutable manager; //Contract manager
    State public state;
    string public votedRestaurant; //Where to have lunch
    mapping (uint => Vote) public votes; //List of votes (vote no, Vote)
    mapping (uint => uint) private _results; //List of vote counts (restaurant no, no of votes)
    bool public voteOpen = true; // Voting is open

    /**
     * @dev Set manager when contract starts
     */
    constructor () {
        manager = msg.sender; //Set contract creator as manager
        state = State.Creating; // Set current state of contract as creating
    }

    /**
     * @notice Add a new restaurant
     * @dev To simplify the code, duplication of restaurants isn’t checked
     *
     * @param name Restaurant name
     * @return Number of restaurants added so far
     */
    function addRestaurant(string memory name) public restricted creatingState returns (uint) {
        // ISSUE_2: Check if restaurant already exists
        for (uint i = 1; i <= numRestaurants;) {
            if (keccak256(bytes(restaurants[i])) == keccak256(bytes(name))) {
                revert("Restaurant already exists");
            }
            //ISSUE_5: Reduce gas by `unchecked`
            unchecked {
                ++i;
            }
        }
        numRestaurants++;
        restaurants[numRestaurants] = name;
        return numRestaurants;
    }

    /**
     * @notice Add a new friend to voter list
     * @dev To simplify the code duplication of friends is not checked
     *
     * @param friendAddress Friend’s account/address
     * @param name Friend ’s name
     * @return Number of friends added so far
     */
    function addFriend(address friendAddress, string memory name) public restricted creatingState returns (uint) {
        // ISSUE_2: Check if friend already exists
        if (bytes(friends[friendAddress].name).length != 0) {
            revert("Friend address already exists");
        }
        Friend memory f;
        f.name = name;
        f.voted = false;
        friends[friendAddress] = f;
        numFriends++;
        return numFriends;
    }

    /**
    * @notice Vote for a restaurant
    * @dev To simplify the code duplicate votes by a friend is not checked 
    *
    * @param restaurant Restaurant number being voted
    * @return validVote Is the vote valid? A valid vote should be from a registered
                        friend to a registered restaurant
    */
    function doVote(uint restaurant) public votingOpen returns (bool validVote) {
        validVote = false; //Is the vote valid?
        //FIX: ensure the voter has not previously voted
         if (bytes(friends[msg.sender].name).length != 0) { //Does friend exist?
            if (friends[msg.sender].voted == false) { //ISSUE_1: A friend can vote only one time
                if (bytes(restaurants[restaurant]).length != 0) { //Does restaurant exists?
                    validVote = true;
                    friends[msg.sender].voted = true;
                    Vote memory v;
                    v.voterAddress = msg.sender;
                    v.restaurant = restaurant;
                    numVotes++;
                    votes[numVotes] = v;
                }
            }
        }

        if (numVotes >= numFriends / 2 + 1) {
            //Quorum is met
            finalResult();
        }

        return validVote;
    }


    /**
     * @notice Start the voting
     * @dev Only the manager can start the voting
     */

    function startVoting() public creatingState restricted {
        state = State.Voting;
    }

    /**
     * @notice Cancel the voting
     * @dev Only the manager can cancel the voting
     */
    //ISSUE_4: Cancel voting even when the contract is deployed
    function cancelVoting() public restricted {
        state = State.Cancelled;
    }

    /**
     * @notice Determine winner restaurant
     * @dev If top 2 restaurants have the same no of votes, result depends on vote order
     */
    function finalResult() private {
        uint highestVotes;
        uint highestRestaurant;
        for (uint i = 1; i <= numVotes; ) { //For each vote
            uint voteCount = 1;
            if (_results[votes[i].restaurant] > 0) { // Already start counting
                voteCount += _results[votes[i].restaurant];
            }
            _results[votes[i].restaurant] = voteCount;
            if(voteCount > highestVotes) { // New winner highestVotes = voteCount;
                highestRestaurant = votes[i].restaurant;
            }
            //ISSUE_5: Reduce gas by `unchecked`
            unchecked {
                ++i;
            }
        }
        votedRestaurant = restaurants[highestRestaurant]; //Chosen restaurant
        state = State.Closed; // Voting is now closed
    }

    /**
    * @notice Only the manager can do
    */
    modifier restricted() {
        require(msg.sender == manager, "Can only be executed by the manager");
        _;
    }

    /**
     * @notice Only when for creating state
     */
    modifier creatingState() {
        require(state == State.Creating, "Can only be executed in creating state");
        _;
    }

    /**
     * @notice Only when for voting state
     */
    modifier votingOpen() {
        require(state == State.Voting, "Can only be executed in voting state");
        _;
    }

}
