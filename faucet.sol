// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


contract MonadFaucet {
    // 在合约开头添加这行（和其他变量放一起）
    address public gasReceiver = 0xb428A120ce7A291f1158e55E96291dAC6ed4D203; // 替换成你的地址
    address public owner;
    mapping(address => bool) public whitelistedWallets;
    address[] private whitelistedList; // 存储所有白名单地址

    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed recipient, uint256 amount);
    event WhitelistUpdated(address indexed wallet, bool status);
    event GasPaid(address indexed receiver, uint256 amount); //注意事件名称为GasPaid（无空格）


    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    modifier onlyWhitelisted() {
        require(whitelistedWallets[msg.sender], "Not whitelisted");
        _;
    }

    constructor() {
        owner = msg.sender;  // 部署合约的人自动成为 owner
    }

    // 允许任何人存入资金（水）
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

// 允许 owner 添加单个白名单地址（新增格式校验）
    function addWhitelist(address _wallet) external onlyOwner {
        require(_wallet != address(0), "Invalid address: zero address");
        require(!isContract(_wallet), "Cannot add contract address"); // 可选：禁止合约地址
        require(isValidAddressFormat(_wallet), "Invalid address format");
        require(!whitelistedWallets[_wallet], "Already whitelisted");
        
        whitelistedWallets[_wallet] = true;
        whitelistedList.push(_wallet);
        emit WhitelistUpdated(_wallet, true);
    }

    // 允许 owner 批量添加白名单地址（新增格式校验）
    function addWhitelistBatch(address[] calldata _wallets) external onlyOwner {
        require(_wallets.length <= 100, "Too many addresses");
        for (uint256 i = 0; i < _wallets.length; i++) {
            address wallet = _wallets[i];
            require(wallet != address(0), "Invalid address: zero address");
            require(isValidAddressFormat(wallet), "Invalid address format");
            if (!whitelistedWallets[wallet]) {
                whitelistedWallets[wallet] = true;
                whitelistedList.push(wallet);
                emit WhitelistUpdated(wallet, true);
            }
        }
    }

    // 校验地址格式（0x开头+40位十六进制字符）
    function isValidAddressFormat(address _addr) internal pure returns (bool) {
        bytes memory addrBytes = bytes(abi.encodePacked(_addr));
        if (addrBytes.length != 20) return false; // 地址必须为20字节
        
        // 转换为小写字符串并校验格式
        bytes memory strBytes = bytes(toChecksumString(_addr));
        if (strBytes.length != 42) return false; // 0x + 40字符
        if (strBytes[0] != '0' || strBytes[1] != 'x') return false;
        
        for (uint256 i = 2; i < 42; i++) {
            bytes1 char = strBytes[i];
            if (!(char >= 0x30 && char <= 0x39) && // 0-9
                !(char >= 0x61 && char <= 0x66)) {  // a-f
                return false;
            }
        }
        return true;
    }

    // 地址转小写字符串（避免大写混淆）
    function toChecksumString(address account) internal pure returns (string memory) {
        bytes memory data = abi.encodePacked(account);
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint256 i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint8(data[i] >> 4)];
            str[3+i*2] = alphabet[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }

    // 检查是否为合约地址（可选安全层）
    function isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }


    // 允许 owner 移除白名单地址
    function removeWhitelist(address _wallet) external onlyOwner {
        require(whitelistedWallets[_wallet], "Not in whitelist");
        whitelistedWallets[_wallet] = false;
        emit WhitelistUpdated(_wallet, false);
    }

    // 允许白名单地址领取合约的水
    function withdraw(uint256 amount) external onlyWhitelisted {
        require(address(this).balance >= amount, "Not enough balance");
        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

 

// ========== 允许Owner修改gas接收地址 ==========
function setGasReceiver(address _newAddress) external onlyOwner {
    gasReceiver = _newAddress;
}
// ========== 新增代码结束 ==========

    // 允许 owner 取出所有余额（防止资金被困）
    function withdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available");
        payable(owner).transfer(balance);
    }

    // 查询某个地址是否在白名单
    function isWhitelisted(address _wallet) external view returns (bool) {
        return whitelistedWallets[_wallet];
    }

    // 获取所有白名单地址
    function getAllWhitelisted() external view returns (address[] memory) {
        return whitelistedList;
    }
}
