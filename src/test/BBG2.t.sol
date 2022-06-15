// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {BaseTest, console} from "./base/BaseTest.sol";
import "../BBG2.sol";

contract BBG2Test is BaseTest {
    address bbg1 = 0x0000000000000000000000000000000000000000;
    address partner = 0x0000000000000000000000000000000000000000;
    address teamMember = 0x4C3490dF15edFa178333445ce568EC6D99b5d71c;
    address teamMember2 = 0x4C3490dF15edFa178333445ce568EC6D99b5d71c;
    BBG2 bbg2;

    function setUp() public {
        bbg2 = new BBG2("Banner Buddies Gen 2",
                            "BBG2",
                            "shitfuck",
                            0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c,
                            0x4C3490dF15edFa178333445ce568EC6D99b5d71c,
                            0x96662f375a9734654cB57BbFeb31Db9dD7784A7F,
                            0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83,
                            0x68874C562EfbBc6e2487FA77B7700064d209D4CA,
                            0,
                            1000,
                            5
                        );
    }

    function testExample() public {
        vm.startPrank(teamMember);
        console.log(bbg2.balanceOf(address(teamMember)), "INIT BALANCE PRE DEPLOY");
        vm.stopPrank();
    }
}
