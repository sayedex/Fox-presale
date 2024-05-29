// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FOX_PRESALE is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    address public token;
    address public treasuryWallet;
    uint256 public constant FIVE_MONTHS = 30 days * 5;
    uint256 public constant ONE_YEAR = 365 days;
    uint256 public PRESALE_ENDTIME = 0;
    uint256 constant TotalRound = 2;
    uint256 public totalSold;
    uint256 public totalRaised;
    uint256 public nextTokenId;

    struct PresaleRound {
        mapping(uint256 => uint256) tokenPrice;
        uint256 tokensSold;
        uint256 endTimestamp;
    }
    struct PaymentToken {
        address _tokenaddress;
        uint8 _decimals;
    }

    struct VestingRecord {
        uint256 amount;
        uint256 deadline;
        bool claimed;
    }

    struct WhiteListedUsers {
        uint256 Percentage;
        bool isWhiteListed;
    }

    struct User {
        uint256 tokenamount;
        uint256 referral;
    }

    struct VestingSchedule {
        uint256 immediateAmount;
        mapping(uint256 => VestingRecord) vestingRecords;
    }
    mapping(uint256 => PresaleRound) public presalePool;
    mapping(uint256 => PaymentToken) public tokenInfo;
    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(uint256 => uint256) public roundDeadline;
    mapping(uint256 => mapping(address => WhiteListedUsers))
        public WhiteListedUser;
    mapping(uint256 => uint256) public refferPercentage;
    mapping(uint256 => uint256) public RoundVestingPercentage;
    mapping(address => User) private userToken;

    event TokensPurchased(address indexed buyer, uint256 amount);
    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(address _token, address _treasuryWallet)  {
        token = (_token);
        treasuryWallet = _treasuryWallet;
        PRESALE_ENDTIME = 1716873345;
        // reffer
        refferPercentage[0] = 10;
        refferPercentage[1] = 20;
        RoundVestingPercentage[0] = 30;
        RoundVestingPercentage[1] = 60;

        roundDeadline[0] = FIVE_MONTHS;
        roundDeadline[1] = ONE_YEAR;

        presalePool[0].tokenPrice[0] = 2000000000000000000;
        presalePool[1].tokenPrice[0] = 2000000000000000000;
    }

    

    function buyTokensVesting(
        uint256 _tokenId,
        uint256 _tokenAmount,
        uint256 _poolId,
        address _referrer
    ) external nonReentrant {
        require(
            tokenInfo[_tokenId]._tokenaddress != address(0),
            "Payment token not set"
        );
        require(_poolId == 1, "_poolId not set");
          transferCurrency(
            tokenInfo[_tokenId]._tokenaddress,
              msg.sender,
            address(this),
            _tokenAmount
        );

        _handleVesting(msg.sender, _tokenId, _tokenAmount, _poolId, _referrer);
    }

    function _handleVesting(
        address buyer,
        uint256 _tokenId,
        uint256 _tokenAmount,
        uint256 _poolId,
        address _referrer
    ) internal {
        uint256 amountTokens = (presalePool[_poolId].tokenPrice[_tokenId] *
            _tokenAmount) / 10**tokenInfo[_tokenId]._decimals;

        uint256 immediateAmount = (amountTokens * 10) / 100;
        VestingSchedule storage schedule = vestingSchedules[buyer];

        schedule.immediateAmount += immediateAmount;
        presalePool[_poolId].tokensSold += amountTokens;
        totalSold += amountTokens;
        totalRaised += _tokenAmount;
        _processPayment_pool_2(_tokenId,_tokenAmount,amountTokens,_poolId,_referrer);
        for (uint256 i = 0; i < TotalRound; i++) {
            schedule.vestingRecords[i] = VestingRecord({
                amount: (amountTokens * RoundVestingPercentage[i]) / 100,
                deadline: roundDeadline[i],
                claimed: false
            });
        }

        transferCurrency(token,treasuryWallet, buyer, immediateAmount);
        emit TokensPurchased(buyer, amountTokens);
    }

    function buyTokens(
        uint256 _tokenId,
        uint256 _tokenAmount,
        uint256 _poolId,
        address _referrer
    ) external nonReentrant {
        require(
            tokenInfo[_tokenId]._tokenaddress != address(0),
            "Payment token not set"
        );
        require(_poolId == 0, "_poolId not set");
        uint256 amountTokens = (presalePool[_poolId].tokenPrice[_tokenId] *
            _tokenAmount) / 10**tokenInfo[_tokenId]._decimals;
        transferCurrency(
            tokenInfo[_tokenId]._tokenaddress,
           msg.sender,
            address(this),
            _tokenAmount
        );
        presalePool[_poolId].tokensSold += amountTokens;
        totalSold += amountTokens;
        totalRaised += _tokenAmount;
        _processPayment_pool_1(_tokenId,_tokenAmount,_poolId,_referrer);
        transferCurrency(token, treasuryWallet, msg.sender, amountTokens);
        emit TokensPurchased(msg.sender, amountTokens);
    }

    function _processPayment_pool_1(
        uint256 _tokenId,
        uint256 _tokenAmount,
        uint256 _poolId,
        address _referrer
    ) internal {
        uint256 _amount;
        uint256 _referrerAmount;

        if (_referrer == address(0)) {
            _amount = _tokenAmount;
        } else {
            if (WhiteListedUser[_poolId][_referrer].isWhiteListed) {
                _referrerAmount =
                    (_tokenAmount *
                        WhiteListedUser[_poolId][_referrer].Percentage) /
                    100;
            } else {
                _referrerAmount = (_tokenAmount * refferPercentage[_poolId]) / 100;
            }

            _amount = _tokenAmount - _referrerAmount;

            transferCurrency(
                tokenInfo[_tokenId]._tokenaddress,
                address(this),
                _referrer,
                _referrerAmount
            );
        }

        uint256 _tokenAmounts1 = (_amount * 5) / 100;

        transferCurrency(
            tokenInfo[_tokenId]._tokenaddress,
            address(this),
            treasuryWallet,
            _tokenAmounts1
        );

        transferCurrency(
            tokenInfo[_tokenId]._tokenaddress,
            address(this),
            treasuryWallet,
            _amount - _tokenAmounts1
        );
    }

    function _processPayment_pool_2(
        uint256 _tokenId,
        uint256 _tokenAmount,
        uint256 _amountTokens,
        uint256 _poolId,
        address _referrer
    ) internal {
        uint256 _amount;
        uint256 _referrerAmount;
        uint256 _reffer_usdt;
        uint256 _referrerImmediateAmount;

        if (_referrer == address(0)) {
            _amount = _tokenAmount;
        } else {
            _reffer_usdt = (_tokenAmount * 5) / 100;
            _amount = _tokenAmount - _reffer_usdt;
            if (WhiteListedUser[_poolId][_referrer].isWhiteListed) {
                _referrerAmount =
                    (_amountTokens *
                        WhiteListedUser[_poolId][_referrer].Percentage) /
                    100;
            } else {
                _referrerAmount = (_amountTokens * refferPercentage[_poolId]) / 100;
            }

            _referrerImmediateAmount = (_referrerAmount * 10) / 100;
            VestingSchedule storage referrerSchedule = vestingSchedules[
                _referrer
            ];

            if (referrerSchedule.vestingRecords[0].amount == 0) {
                for (uint256 i = 0; i < TotalRound; i++) {
                    referrerSchedule.vestingRecords[i] = VestingRecord({
                        amount: (_amount * RoundVestingPercentage[i]) / 100,
                        deadline: roundDeadline[i],
                        claimed: false
                    });
                }
            } else {
                for (uint256 i = 0; i < TotalRound; i++) {
                    referrerSchedule.vestingRecords[i].amount +=
                        (_amount * RoundVestingPercentage[i]) /
                        100;
                }
            }

            transferCurrency(
                token,
                treasuryWallet,
                _referrer,
                _referrerImmediateAmount
            );
            transferCurrency(
                tokenInfo[_tokenId]._tokenaddress,
                address(this),
                _referrer,
                _reffer_usdt
            );
        }

        uint256 _tokenAmounts1 = (_amount * 5) / 100;


        transferCurrency(
            tokenInfo[_tokenId]._tokenaddress,
            msg.sender,
            treasuryWallet,
            _tokenAmounts1
        );

        transferCurrency(
            tokenInfo[_tokenId]._tokenaddress,
            msg.sender,
            treasuryWallet,
            _amount - _tokenAmounts1
        );
    }

    function releaseTokens() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.immediateAmount > 0, "No tokens to release");
        uint256 releasable;
        for (uint256 i = 0; i < TotalRound; i++) {
            if (
                block.timestamp >=
                schedule.vestingRecords[i].deadline + PRESALE_ENDTIME &&
                !schedule.vestingRecords[i].claimed
            ) {
                releasable += schedule.vestingRecords[i].amount;
                schedule.vestingRecords[i].claimed = true;
            }
        }

        require(releasable > 0, "No tokens are due");
        transferCurrency(token, address(this), msg.sender, releasable);
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

        for (uint256 i = 0; i < TotalRound; i++) {
            if (
                block.timestamp >=
                schedule.vestingRecords[i].deadline + PRESALE_ENDTIME &&
                !schedule.vestingRecords[i].claimed
            ) {
                _claimable += schedule.vestingRecords[i].amount;
            } else if (!schedule.vestingRecords[i].claimed) {
                _locked += schedule.vestingRecords[i].amount;
            }
        }

        return (_claimable, _locked);
    }

    function setPresaleEndTime(uint256 _PRESALE_ENDTIME) external onlyOwner {
        require(block.timestamp > _PRESALE_ENDTIME, "time short");
        PRESALE_ENDTIME = _PRESALE_ENDTIME;
    }

    function setPaymentToken(address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(0), "Invalid token address");
        tokenInfo[nextTokenId] = PaymentToken({
            _tokenaddress: _tokenAddress,
            _decimals: IERC20Metadata(_tokenAddress).decimals()
        });
        nextTokenId++;
    }

    function setPrice(
        uint256 _poolId,
        uint256 _tokenId,
        uint256 _price
    ) external onlyOwner {
        presalePool[_poolId].tokenPrice[_tokenId] = _price;
    }

    function withdrawEther(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }

    function setTreasuryWallet(address _newTreasuryWallet) external onlyOwner {
        require(
            _newTreasuryWallet != address(0),
            "Invalid treasury wallet address"
        );
        treasuryWallet = _newTreasuryWallet;
    }

    function setRefferPercentage(uint256 _poolId, uint256 value)
        external
        onlyOwner
    {
        refferPercentage[_poolId] = value;
    }

    function setWhiteListedUser(
        uint256 _poolId,
        address _user,
        uint256 _percentage,
        bool _isWhiteListed
    ) external onlyOwner {
        WhiteListedUser[_poolId][_user] = WhiteListedUsers({
            Percentage: _percentage,
            isWhiteListed: _isWhiteListed
        });
    }

    /// @dev Transfers a given amount of currency.
    function transferCurrency(
        address _currency,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        if (_amount == 0) {
            return;
        }
        safeTransferERC20(_currency, _from, _to, _amount);
    }

    // @dev Transfer `amount` of ERC20 token from `from` to `to`.
    function safeTransferERC20(
        address _currency,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        if (_from == _to) {
            return;
        }

        if (_from == address(this)) {
            IERC20(_currency).safeTransfer(_to, _amount);
        } else {
            IERC20(_currency).safeTransferFrom(_from, _to, _amount);
        }
    }

    receive() external payable {}

    function getUserpurchase(address user)
        external
        view
        returns (uint256, uint256)
    {
        return (userToken[user].tokenamount, userToken[user].referral);
    }
}
