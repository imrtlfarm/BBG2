// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract MockLGE {
    mapping(address => uint) public terms;

    function setTerms(uint term) public {
        terms[msg.sender] = term;
    }
}

