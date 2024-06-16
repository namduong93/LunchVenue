// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.5;
// This import is automatically injected by Remix
import "remix_tests.sol";
// This import is required to use custom transaction context
// Although it may fail compilation in ’Solidity Compiler’ plugin // But it will work fine in ’Solidity Unit Testing’ plugin
import "remix_accounts.sol";
import {LunchVenueUpdated} from "../contracts/LunchVenue_updated.sol";

// File name has to end with ’_test.sol’, this file can contain more than one testSuite contracts

/// @title Contract to test LunchVenueUpdated
/// @author Van Nam Duong, UNSW (z5412692)
/// @notice There are two test files to test LunchVenueUpdated, this file is tests all possible cases except the voting is being cancelled

/// Inherit ’LunchVenue’ contract
contract LunchVenueTest is LunchVenueUpdated {
    // Variables used to emulate different accounts
    address acc0;
    address acc1;
    address acc2;
    address acc3;
    address acc4;
    address acc5;

    /// ’beforeAll’ runs before all other tests
    /// More special functions are: ’beforeEach’, ’beforeAll’, ’afterEach’ & ’afterAll’
    function beforeAll() public {
        // Initiate account variables
        acc0 = TestsAccounts.getAccount(0); // Alice
        acc1 = TestsAccounts.getAccount(1); // Bob
        acc2 = TestsAccounts.getAccount(2); // Charlie
        acc3 = TestsAccounts.getAccount(3); // Dave
        acc4 = TestsAccounts.getAccount(4); // Eve
        acc5 = TestsAccounts.getAccount(5); // John
    }

    /// Constructor Check
    function constructorTest() public {
        Assert.equal(numRestaurants, 0, "The num of restaurants should be 0");
        Assert.equal(numFriends, 0, "The num of friends should be 0");
        Assert.equal(numVotes, 0, "The num of votes should be 0");
        Assert.equal(votedRestaurant, "", "The voted restaurant should be empty");
        Assert.equal(manager, acc0, "Manager should be acc0");
        Assert.equal(uint(state), uint(LunchVenueUpdated.State.Creating), "State should be Creating");
    }

    /* Test Cases for Creating State */

    /// Check manager
    /// account-0 is the default account that deploy contract, so it should be the manager (i.e., acc0)
    function managerTest() public {
        Assert.equal(manager, acc0, "Manager should be acc0");
    }

    /// Add restaurant as manager
    /// When msg.sender isn’t specified, default account (i.e., account-0) is the sender
    function setRestaurant() public {
        Assert.equal(addRestaurant("Courtyard Cafe"), 1, "Should be equal to 1");
        Assert.equal(addRestaurant("Uni Cafe"), 2, "Should be equal to 2");
    }

    /// Try to add a restaurant as a user other than manager. This should fail
    /// #sender: account-1 (Bob)
    function setRestaurantFailure2() public {
        bytes memory methodSign = abi.encodeWithSignature("addRestaurant(string)", "Cat Cafe");
        (bool success, ) = address(this).call(methodSign);
        Assert.equal(success, false, "execution should not be successful");
    }

    /// Try to add the same restaurant again. The latter should fail to add
    function setSameRestaurant() public {
        // add third restaurant
        Assert.equal(addRestaurant("UNSW Cafe"), 3, "Should be equal to 3");
        // add the same restaurant again
        bytes memory methodSign = abi.encodeWithSignature("addRestaurant(string)", "UNSW Cafe");
        (bool success, ) = address(this).call(methodSign);
        Assert.equal(success, false, "execution should not be successful");
    }

    /// Set friends as account-0 (Alice)
    /// #sender doesn’t need to be specified explicitly for account-0
    function setFriend() public {
        Assert.equal(addFriend(acc0, "Alice"), 1, "Should be equal to 1");
        Assert.equal(addFriend(acc1, "Bob"), 2, "Should be equal to 2");
        Assert.equal(addFriend(acc2, "Charlie"), 3, "Should be equal to 3");
        Assert.equal(addFriend(acc3, "Dave"), 4, "Should be equal to 4");
    }

    /// Try adding friend as a user other than manager. This should fail
    /// #sender: account-1 (Bob)
    function setFriendFailure() public {
        bytes memory methodSign = abi.encodeWithSignature("addFriend(address, string)", acc4, "Daves");
        (bool success, ) = address(this).call(methodSign);
        Assert.equal(success, false, "execution should not be successful");
    }

    /// Try to add the same friend again. The latter should fail to add
    function setSameFriend() public {
        Assert.equal(addFriend(acc5, "John"), 5, "Should be equal to 5");
        // add the same friend again
        bytes memory methodSign1 = abi.encodeWithSignature("addFriend(address, string)", acc5, "John");
        (bool success1, ) = address(this).call(methodSign1);
        Assert.equal(success1, false, "execution should not be successful");

        // add the same address but different name
        bytes memory methodSign2 = abi.encodeWithSignature("addFriend(address, string)", acc5, "James");
        (bool success2, ) = address(this).call(methodSign2);
        Assert.equal(success2, false, "execution should not be successful");
    }

    /// No one can vote during Creating state
    /// #sender: account-0 (Alice)
    function doVoteFailure0() public {
        bytes memory methodSign = abi.encodeWithSignature("doVote(uint)", 1);
        (bool success, ) = address(this).call(methodSign);
        Assert.equal(success, false, "execution should not be successful");
    }

    /// No one can vote during Creating state
    /// #sender: account-1 (Bob)
    function doVoteFailure1() public {
        bytes memory methodSign = abi.encodeWithSignature("doVote(uint)", 1);
        (bool success, ) = address(this).call(methodSign);
        Assert.equal(success, false, "execution should not be successful");
    }

    /// Set to voting state
    /// #sender: account-0 (Alice)
    function setVotingState() public {
        // Set voting state
        startVoting();
        Assert.equal(uint(state), uint(LunchVenueUpdated.State.Voting), "State should be Voting"
        );
    }

    // /* Test Cases for Voting State */

    /// Cancel voting as a user other than manager. This should fail.
    /// #sender: account-1 (Bob)
    function cancelVotingFailure() public {
        bytes memory methodSign = abi.encodeWithSignature("cancelVoting()");
        (bool success, ) = address(this).call(methodSign);
        Assert.equal(success, false, "execution should not be successful");
    }


    /// Try voting as a user not in the friends list. This should fail.
    /// Vote as Bob (acc1)
    /// #sender: account-1 (Bob)
    function vote1() public {
        Assert.ok(doVote(2), "Voting result should be true");
        Assert.equal(numVotes, 1, "Number of votes should be 1");
    }

    /// Vote as Charlie
    /// #sender: account-2 (Charlie)
    function vote2() public {
        Assert.ok(doVote(1), "Voting result should be true");
        Assert.equal(numVotes, 2, "Number of votes should be 2");
    }

    /// Try voting as a user not in the friends list. This should fail.
    /// #sender: account-5 (John)
    function voteFailure() public {
        bytes memory methodSign = abi.encodeWithSignature("doVote(uint)", 1);
        (bool success, ) = address(this).call(methodSign);
        Assert.equal(success, false, "execution should not be successful");
    }

    /// Try voting for a restaurant not in the restaurant list. This should fail.
    /// #sender: account-3 (Dave)
    function voteFailure2() public {
        bytes memory methodSign = abi.encodeWithSignature("doVote(uint)", 4);
        (bool success, ) = address(this).call(methodSign);
        Assert.equal(success, false, "execution should not be successful");
    }

    /// Vote again from Charlie
    /// #sender: account-2 (Charlie)
    function voteFailure3() public {
        bytes memory methodSign = abi.encodeWithSignature("doVote(uint)", 2);
        (bool success, ) = address(this).call(methodSign);
        Assert.equal(success, false, "execution should not be successful");
    }

    /// Vote as Dave
    /// #sender: account-3 (Dave)
    function vote3() public {
        Assert.ok(doVote(2), "Voting result should be true");
        Assert.equal(numVotes, 3, "Number of votes should be 3");
    }

    /// ISSUE_6: Testing restaurant with invalid number
    function vote4() public {
        bytes memory methodSign = abi.encodeWithSignature("doVote(uint)", 10);
        (bool success, ) = address(this).call(methodSign);
        Assert.equal(success, false, "execution should not be successful");
    }

    /// Verify lunch venue is set correctly.
    function lunchVenueResult() public {
        Assert.equal(votedRestaurant, "Uni Cafe", "Selected restaurant should be Uni Cafe");
        Assert.equal(uint(state), uint(LunchVenueUpdated.State.Closed), "State should be ended");
    }

    /* Test Cases for Ended State */

    /// Verify voting after vote closed. This should fail
    /// Voted by Alice (who previous has not voted before finalize)
    function voteAfterClosedFailure() public {
        bytes memory methodSign = abi.encodeWithSignature("doVote(uint)", 1);
        (bool success, ) = address(this).call(methodSign);
        Assert.equal(success, false, "execution should not be successful");
    }

    /// Verify voting after vote closed. This should fail
    /// #sender: account-2 (Charlie)
    function voteAfterClosedFailure2() public {
        bytes memory methodSign = abi.encodeWithSignature("doVote(uint)", 2);
        (bool success, ) = address(this).call(methodSign);
        Assert.equal(success, false, "execution should not be successful");
    }
    
    function cancelVotingSuccess() public {
        cancelVoting();
        Assert.equal(uint(state), uint(LunchVenueUpdated.State.Cancelled), "State should be Cancelled");
    }
}

