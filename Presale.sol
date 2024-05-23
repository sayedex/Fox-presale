// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenPresale is Ownable {
    IERC20 public token;
    uint256 public constant FIVE_MONTHS = 30 days * 5;
    uint256 public constant ONE_YEAR = 365 days;
    uint256 public PRESALE_ENDTIME = 0;
    uint256 constant TotalRound = 2;

    struct VestingRecord {
        uint256 amount;
        uint256 deadline;
        bool claimed;
    }
    struct VestingSchedule {
        uint256 immediateAmount;
        mapping(uint256 => VestingRecord) vestingRecords;
    }

    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(uint256 => uint256) public roundDeadline;
    mapping(address => bool) public WhiteListedUser;
    mapping(uint256 => uint256) public refferParchange;
    mapping(uint256 => uint256) public RoundVestingParchange;

    event TokensPurchased(address indexed buyer, uint256 amount);
    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(address _token) Ownable(msg.sender) {
        token = IERC20(_token);
        PRESALE_ENDTIME = 10;
        // 10% reward for 1st pool..
        refferParchange[0] = 10;
        // 20% reward for 2nd pool..
        refferParchange[1] = 20;

        // add round vesting deadline for each
        roundDeadline[0] = FIVE_MONTHS;
        roundDeadline[1] = ONE_YEAR;
    }

    function buyTokens(uint256 amount) external {
        // instant unlocking ..
        uint256 immediateAmount = (amount * 10) / 100;
        uint256 tokenAmount = amount;

        VestingSchedule storage schedule = vestingSchedules[msg.sender];

        if (schedule.immediateAmount == 0) {
            schedule.immediateAmount = immediateAmount;
        } else {
            schedule.immediateAmount += immediateAmount;
        }

        for (uint256 i = 0; i < TotalRound; i++) {
            schedule.vestingRecords[i] = VestingRecord({
                amount: (tokenAmount * RoundVestingParchange[i]) / 100,
                deadline: roundDeadline[i],
                claimed: false
            });
        }

        require(
            token.transfer(msg.sender, immediateAmount),
            "Token transfer failed"
        );

        emit TokensPurchased(msg.sender, amount);
    }

    function _handleReferral(
        address referrer,
        uint256 tokenamount,
        uint256 _poolId
    ) internal {
        uint256 _amount;

        _amount = (tokenamount * refferParchange[_poolId]) / 100;
        if (WhiteListedUser[referrer]) {
            _amount = (tokenamount * refferParchange[_poolId]) / 100;
        }
        uint256 referrerImmediateAmount = (_amount * 10) / 100;
        VestingSchedule storage referrerSchedule = vestingSchedules[referrer];

        if (
            referrerSchedule
                .vestingRecords[0]
                .amount == 0
        ) {
            for (uint256 i = 0; i < TotalRound; i++) {
                referrerSchedule.vestingRecords[i] = VestingRecord({
                    amount: (_amount * RoundVestingParchange[i]) / 100,
                    deadline: roundDeadline[i],
                    claimed: false
                });
            }
        } else {
            for (uint256 i = 0; i < TotalRound; i++) {
                referrerSchedule.vestingRecords[i].amount +=
                    (_amount * RoundVestingParchange[i]) /
                    100;
            }
        }

        require(
            token.transfer(referrer, referrerImmediateAmount),
            "Token transfer to referrer failed"
        );
    }

    function releaseTokens() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.immediateAmount > 0, "No tokens to release");

        uint256 releasable = schedule.immediateAmount;
        for (uint256 i = 0; i < TotalRound; i++) {
            if (
                block.timestamp >=
                schedule.vestingRecords[i].deadline + PRESALE_ENDTIME &&
                !schedule.vestingRecords[i].claimed
            ) {
                releasable += schedule.vestingRecords[roundDeadline[i]].amount;
                schedule.vestingRecords[roundDeadline[i]].claimed = true;
            }
        }

        require(releasable > 0, "No tokens are due");
        require(
            token.transfer(msg.sender, releasable),
            "Token transfer failed"
        );

        emit TokensReleased(msg.sender, releasable);
    }

    function getTokenStatus(address beneficiary)
        external
        view
        returns (uint256 claimable, uint256 locked)
    {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        uint256 _claimable = 0;
        uint256 _locked = 0;

        if (schedule.immediateAmount > 0) {
            _claimable += schedule.immediateAmount;
        }

        for (uint256 i = 0; i < TotalRound; i++) {
            if (
                block.timestamp >=
                schedule.vestingRecords[roundDeadline[i]].deadline +
                    PRESALE_ENDTIME &&
                !schedule.vestingRecords[roundDeadline[i]].claimed
            ) {
                _claimable += schedule.vestingRecords[roundDeadline[i]].amount;
            } else if (!schedule.vestingRecords[roundDeadline[i]].claimed) {
                _locked += schedule.vestingRecords[roundDeadline[i]].amount;
            }
        }

        return (_claimable, _locked);
    }

    function withdrawTokens(uint256 amount) external onlyOwner {
        require(token.transfer(owner(), amount), "Token transfer failed");
    }

    function setPresaleEndTime(uint256 _PRESALE_ENDTIME) external onlyOwner {
        require(block.timestamp > _PRESALE_ENDTIME, "time short");
        PRESALE_ENDTIME = _PRESALE_ENDTIME;
    }

    function withdrawEther(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }

    receive() external payable {}
}
