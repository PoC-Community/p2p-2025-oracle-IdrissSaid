// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Oracle {
    struct Round {
        uint256 id;
        uint256 totalSubmissionCount;
        uint256 lastUpdatedAt;
    }

    address public owner;
    address[] public nodes;
    mapping(address => bool) public isNode;

    mapping(string => Round) public rounds;
    mapping(string => mapping(uint256 => mapping(address => uint256))) public nodePrices;
    mapping(string => mapping(uint256 => mapping(address => bool))) public hasSubmitted;

    mapping(string => uint256) public currentPrices;

    event NodeRegistered(address _node);
    event NodeUnregistered(address _node);
    event PriceUpdated(string indexed coin, uint256 price, uint256 roundId);

    constructor() {
        owner = msg.sender;
    }

    function getQuorum() public view returns (uint256) {
        if (nodes.length < 3) {
            return 3;
        }
        return (nodes.length * 2 + 2) / 3;
    }

    function addNode() public {
        require(!isNode[msg.sender], "Node already exists");
        isNode[msg.sender] = true;
        nodes.push(msg.sender);
        emit NodeRegistered(msg.sender);
    }

    function removeNode() public {
        require(isNode[msg.sender], "Node does not exist");
        isNode[msg.sender] = false;

        // Remove from array using swap and pop
        for (uint256 i = 0; i < nodes.length; i++) {
            if (nodes[i] == msg.sender) {
                nodes[i] = nodes[nodes.length - 1];
                nodes.pop();
                break;
            }
        }
        emit NodeUnregistered(msg.sender);
    }

    function submitPrice(string memory coin, uint256 price) public {
        require(isNode[msg.sender], "Not a node");

        uint256 roundId = rounds[coin].id;
        require(!hasSubmitted[coin][roundId][msg.sender], "Already submitted for this round");

        nodePrices[coin][roundId][msg.sender] = price;
        hasSubmitted[coin][roundId][msg.sender] = true;
        rounds[coin].totalSubmissionCount++;

        if (rounds[coin].totalSubmissionCount >= getQuorum()) {
            _finalizePrice(coin, roundId);
        }
    }

    function _finalizePrice(string memory coin, uint256 roundId) internal {
        uint256 totalPrice = 0;
        uint256 validSubmissions = 0;

        for (uint256 i = 0; i < nodes.length; i++) {
            address node = nodes[i];
            if (hasSubmitted[coin][roundId][node]) {
                totalPrice += nodePrices[coin][roundId][node];
                validSubmissions++;
            }
        }

        if (validSubmissions > 0) {
            uint256 avgPrice = totalPrice / validSubmissions;
            currentPrices[coin] = avgPrice;
            emit PriceUpdated(coin, avgPrice, roundId);
        }

        rounds[coin].id++;
        rounds[coin].totalSubmissionCount = 0;
        rounds[coin].lastUpdatedAt = block.timestamp;
    }
}
