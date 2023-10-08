// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Oxkyng} from "../src/Oxkyng.sol";

contract OxkyngTest is Test {
    Oxkyng public oxkyng;

    address public weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;


    function setUp() public {
        oxkyng = new Oxkyng{value: msg.value}(weth);
        
    }


}
