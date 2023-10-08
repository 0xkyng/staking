// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router01} from "./interfaces/IUniswapV2Router01.sol";
import {RewardToken} from "./RewardToken.sol";


contract Oxkyng is ERC20 {


     address public Weth;
     address public weth_to_oxk;
     RewardToken public rewardToken;

     uint256 public compounders;
      uint256 public executorsPay;

    struct User {
        uint256 stakedAmount;
        uint256 stakingDuration;
        uint256 stakingRewards;
        bool autoCompound;
        uint256 lastTimeStaked;
        bool isStakingActive;
       
    }

    mapping(address => User) public users;
     address[] public usersCompounding;
    address[] public usersNotCompounding;



     constructor(address _Weth) payable ERC20("Oxkyng", "OXK") {
        Weth = _Weth;
        owner = msg.sender;
        _mint(msg.sender, 1000 * 1e18);
        IUniswapV2Router01 V2Router = IUniswapV2Router01(
            0xf164fC0Ec4E93095b804a4795bBe1e041497b92a
        );
        IERC20(address(this)).approve(
            address(V2Router),
            balanceOf(address(this)) * 10 ** 18
        );
        V2Router.addLiquidityETH{value: msg.value}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 1 days
        );
    }

    
     // stake tokens
    function stake(bool _compound) external payable {
        
        require(msg.value >= 1 ether, "Cannot stake below 1 ether");

        IWETH(Weth).deposit{value: msg.value}();

        uint lastStake = block.timestamp -
            users[msg.sender].lastTimeStaked;
        uint rewards = users[msg.sender].stakingRewards;

        User memory _user = users(
            msg.value,
            block.timestamp,
            lastStake,
            rewards,
            true,
            _compound
        );
        users[msg.sender] = _user;

        uint one_percent_fee = (msg.value * 1) / 100;

        if (users[msg.sender].usersCompounding) {
            compounders += one_percent_fee ;
            _mint(msg.sender, msg.value - one_percent_fee);
            usersCompounding.push(msg.sender);
        } else {
            _mint(msg.sender, msg.value);
            usersNotCompounding.push(msg.sender);
        }

    }

    function swapOxkToWeth(uint256 _oxkAmtIn) internal {

        IUniswapV2Router01 V2Router = IUniswapV2Router01(
            0xf164fC0Ec4E93095b804a4795bBe1e041497b92a
        );
        address[] memory path = new address[](2);

        path[0] = address(this);
        path[1] = Weth;

        V2Router.swapExactTokensForTokens(
            _oxkAmtIn,
            0,
            path,
            address(this),
            block.timestamp + 5 days
        );
    }

    // calculate staking reward at 14% per annum
    function calcRewards(
    ) internal view returns (uint256) {
        User memory _user = users[msg.sender];
        uint256 stakingDuration = block.timestamp - _user.stakingDuration;
        uint256 stakingRewards = (stakingDuration *
            14 *
            users[msg.sender].stakedAmount) /
            365 days /
            100;
        return stakingRewards;
    }

    function optAutoCompounding() external {
        require(users[msg.sender].usersCompounding, "Auto compounding is On");
        users[msg.sender].usersCompounding = true;
        uint one_percent_fee = (users[msg.sender].stakedAmount * 1) / 100;
        users[msg.sender].stakedAmount - one_percent_fee;
        compondingPool += one_percent_fee;
        usersCompounding.push(msg.sender);
    }

     function sharePercentageFee() internal view returns (uint256 share) {
        uint one_percent_fee = (users[id].stakedAmount * 1) / 100;
        share = one_percent_fee / 2;
    }

    function startCompounding() external {
        for (uint256 i = 0; i < usersCompounding.length; i++) {
            address _user = usersCompounding[i];
            if (
                block.timestamp - User[_user].stakedTime <
                30 days ||
                User[_user].stakingRewards == 0
            ) {
                continue;
            }
            uint256 stakingReward = calcRewards(_user);
            uint rewards = users[_user].stakingReward = 0;

            uint256 prevBal = IERC20(Weth).balanceOf(address(this));

            swapOxkToWeth(stakingRewards);

            uint256 balAfter = IERC20(Weth).balanceOf(address(this));

            uint256 diff = balAfter - prevBal;
            _mint(_user, diff);

            uint lastStake = users[_user].lastTimeStaked;

            bool comp = users[_user].usersCompounding;

            User memory _user = User(
                diff,
                block.timestamp,
                lastStake,
                rewards,
                true,
                comp
            );
            users[_user] = User;

            uint pay = sharePercentageFee(_user);
            executorsPay += pay;
        }

        IERC20(Weth).transfer(msg.sender, executorsPay);

    }

    function withdrawTokensAndRewards() external {
        require(block.timestamp < users[msg.sender].stakingDuration + 14 days, "Not time for withdrawal yet");
    
        require(users[msg.sender].isStakingActive == true, "No active staking");

        uint256 allReward = calcRewards(msg.sender);

        uint256 amount = users[msg.sender].stakingAmount;

        delete users[msg.sender];
        _burn(msg.sender, amount);

        IWETH(Weth).withdraw(amount);

        IERC20(address(this)).transfer(msg.sender, stakingReward);
        (bool s, ) = payable(msg.sender).call{value: amount}("");
        require(s);
    }


    
}
