// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {BaseTest, console} from "./base/BaseTest.sol";
import "../BBG2V2.sol";

interface ICircus {
    function walletOfOwner(address _owner) external returns(uint256[] memory);
}
contract BBG2Test is BaseTest {
    address discount = 0x0000000000000000000000000000000000000000;
    address partner = 0x46DF5672a9bA6dd5A87C5f1224263F06392861F9; //circus for testing
    address teamMember = 0x4C3490dF15edFa178333445ce568EC6D99b5d71c; //tester wallet
    address teamMember2 = 0xdDf169Bf228e6D6e701180E2e6f290739663a784; //roosh
    address user = 0x4cea75f8eFC9E1621AC72ba8C2Ca5CCF0e45Bb3d; //guy i found who owns lotta stuff

    IERC721Enumerable bbg1 = IERC721Enumerable(0x70e6d946bBD73531CeA997C28D41De9Ba52Ac905);
    BBG2V2 bbg2v2;
    address wftm = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
    function setUp() public {
        vm.startPrank(teamMember);
        bbg2v2 = new BBG2V2("Banner Buddies Gen 2",
                            "BBG2",
                            "shitfuck",
                            0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c, //lp
                            0x4C3490dF15edFa178333445ce568EC6D99b5d71c, //royalty address
                            wftm, //wftm
                            0, //royalty amount
                            1000, //max supply
                            5 //max mint
                        );
        bbg2v2.pausePublic(false);
        bbg2v2.addCurrency(wftm, 30e18);
        vm.stopPrank();                   
    }

    function testSuccessMint() public {
        vm.startPrank(user);
        console.log(bbg2v2.balanceOf(address(user)), "INIT BALANCE PRE MINT");
        uint size = 1;
        uint[] memory bbid = new uint[](size);
        uint[] memory pid = new uint[](size);
        bbid[0] = 1276;
        pid[0] = 1068;
        IERC20(wftm).approve(address(bbg2v2),30e30);
        IERC721(bbg1).approve(address(bbg2v2),1276);
        bbg2v2.mint(wftm, 1, discount, bbid, pid);
        console.log("MINTED ID ", bbg2v2.walletOfOwner(address(user))[0]);
        //a
        vm.stopPrank();
    }

    function testSuccessMint5() public {
        vm.startPrank(user);
        console.log(bbg2v2.balanceOf(address(user)), "INIT BALANCE PRE MINT");
        uint size = 5;
        uint[] memory bbid = ICircus(address(bbg1)).walletOfOwner(user);
        uint[] memory cid = ICircus(address(partner)).walletOfOwner(user);
       
        IERC20(wftm).approve(address(bbg2v2),30e30);
        for(uint i = 0; i < bbid.length; i++){
            IERC721(bbg1).approve(address(bbg2v2),bbid[i]);
        }
        
        bbg2v2.mint(wftm, size, discount, bbid, cid);
        uint[] memory ids = bbg2v2.walletOfOwner(address(user));
        for(uint i = 0; i < bbid.length; i++){
            console.log("MINTED ID " , ids[i]);
        }
        vm.stopPrank();
    }

    function testFailMintDoesNotOwnBB() public {
        vm.startPrank(user);
        console.log(bbg2v2.balanceOf(address(user)), "INIT BALANCE PRE MINT");
        uint size = 1;
        uint[] memory bbid = new uint[](size);
        uint[] memory pid = new uint[](size);
        bbid[0] = 1;
        pid[0] = 1068;
        IERC20(wftm).approve(address(bbg2v2),30e30);
        IERC721(bbg1).approve(address(bbg2v2),1276);
        bbg2v2.mint(wftm, 1, discount, bbid, pid);
        console.log(bbg2v2.balanceOf(address(user)), "BALANCE POST FAILED MINT");
        vm.stopPrank();
    }
}
