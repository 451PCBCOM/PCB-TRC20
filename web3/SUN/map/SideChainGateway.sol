// TRC20SUNmapping (2022) by www.451pcb.com
// 
// Forked from SunChain by 451PCB
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.

// pragma solidity ^0.4.19;

pragma solidity ^0.5.12;

import "./ITRC20Receiver.sol";
import "./DAppTRC20.sol";
import "./ECVerify.sol";
import "./Ownable.sol";

contract SideChainGateway is ITRC20Receiver, Ownable {
    using ECVerify for bytes32;

    // 1. deployDAppTRC20AndMapping
    // 4. depositTRC20
    // 6. depositTRX

    event DeployDAppTRC20AndMapping(address mainChainAddress, address sideChainAddress, uint256 nonce);

    event DepositTRC20(address to, address sideChainAddress, uint256 value, uint256 nonce);
    event DepositTRX(address to, uint256 value, uint256 nonce);

    uint256 public numOracles;
    address public sunTokenAddress;
    address mintTRXContract = address(0x10000);
    uint256 public bonus;
    bool public pause;
    bool public stop;

    mapping(address => address) public mainToSideContractMap;
    mapping(address => address) public sideToMainContractMap;
    address[] public mainContractList;
    mapping(uint256 => bool) public tokenIdMap;
    mapping(address => bool) public oracles;

    mapping(uint256 => SignMsg) public depositSigns;
    mapping(uint256 => SignMsg) public mappingSigns;

    struct SignMsg {
        mapping(address => bool) oracleSigned;
        bytes[] signs;
        address[] signOracles;
        uint256 signCnt;
        bool success;
    }

    modifier onlyOracle {
        require(oracles[msg.sender], "oracles[msg.sender] is false");
        _;
    }

    modifier isHuman() {
        require(msg.sender == tx.origin, "not allow contract");
        _;
    }

  
    modifier onlyNotPause {
        require(!pause, "pause is true");
        _;
    }

    modifier onlyNotStop {
        require(!stop, "stop is true");
        _;
    }

 
    function addOracle(address _oracle) public goDelegateCall onlyOwner {
        require(_oracle != address(0), "this address cannot be zero");
        require(!oracles[_oracle], "_oracle is oracle");
        oracles[_oracle] = true;
        numOracles++;
    }

    function delOracle(address _oracle) public goDelegateCall onlyOwner {
        require(oracles[_oracle], "_oracle is not oracle");
        oracles[_oracle] = false;
        numOracles--;
    }

    function setSunTokenAddress(address _sunTokenAddress) public goDelegateCall onlyOwner {
        require(_sunTokenAddress != address(0), "_sunTokenAddress == address(0)");
        sunTokenAddress = _sunTokenAddress;
    }

 
    // 1. deployDAppTRC20AndMapping
 
    function deployDAppTRC20AndMapping(address mainChainAddress, string memory name,
        string memory symbol, uint8 decimals, uint256 nonce) internal
    {
        require(mainToSideContractMap[mainChainAddress] == address(0), "TRC20 contract is mapped");
        address sideChainAddress = address(new DAppTRC20(address(this), name, symbol, decimals));
        mainToSideContractMap[mainChainAddress] = sideChainAddress;
        sideToMainContractMap[sideChainAddress] = mainChainAddress;
        emit DeployDAppTRC20AndMapping(mainChainAddress, sideChainAddress, nonce);
        mainContractList.push(mainChainAddress);
    }

 
    // 4. depositTRC20

    function depositTRC20(address to, address sideChainAddress, uint256 value, uint256 nonce) internal {
        IDApp(sideChainAddress).mint(to, value);
        emit DepositTRC20(to, sideChainAddress, value, nonce);
    }

    // 6. depositTRX
 
    function depositTRX(address payable to, uint256 value, uint256 nonce) internal {
        mintTRXContract.call(abi.encode(value));
        to.transfer(value);
        emit DepositTRX(to, value, nonce);
    }

    function countSuccess(bytes32 ret) internal returns (uint256 count) {
        uint256 _num = uint256(ret);
        for (; _num > 0; ++count) {_num &= (_num - 1);}
        return count;
    }

    function() goDelegateCall onlyNotPause onlyNotStop payable external {
        revert("not allow function fallback");
    }

    function setPause(bool isPause) external goDelegateCall onlyOwner {
        pause = isPause;
    }

    function setStop(bool isStop) external goDelegateCall onlyOwner {
        stop = isStop;
    }

    function getMainContractList() view public returns (address[] memory) {
        return mainContractList;
    }

    function mappingDone(uint256 nonce) view public returns (bool) {
        return mappingSigns[nonce].success;
    }

    function setTokenOwner(address tokenAddress, address tokenOwner) external onlyOwner {
        address(0x10002).call(abi.encode(tokenAddress, tokenOwner));
    }

    function mainContractCount() view external returns (uint256) {
        return mainContractList.length;
    }

    function depositDone(uint256 nonce) view external returns (bool r) {
        r = depositSigns[nonce].success;
    }

    function isOracle(address _oracle) view public returns (bool) {
        return oracles[_oracle];
    }

}
