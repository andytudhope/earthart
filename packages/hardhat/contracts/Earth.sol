// SPDX-License-Identifier: MIT
/*
 * This contract is a fork of the Mintplex ERC721A implementation. It changes certain things:
 * 1. Removes the Provider Fee.
 * 2. Removes the initializable proxy feature, setting things up in the constructor instead.
 * 3. Changed the compiler version to be standard across all contracts
*/
pragma solidity ^0.8.7;

error ERC20TokenNoApprove();
error ERC20LowAllowance();
error ERC20LowBalance();
error ValueNotZero();

import "./openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./openzeppelin/contracts/access/Ownable.sol";

import "./ERC721A.sol";
import "./Teams.sol";
import "./Tippable.sol";
import {Allowlist, Withdrawable, IERC20} from "./Withdrawable.sol";
  
contract Earth is 
    Ownable,
    Teams,
    ERC721A,
    Withdrawable,
    ReentrancyGuard,
    Tippable,
    Allowlist 
{
  constructor(
    address _owner,
    address[] memory _payables,
    uint256[] memory _payouts,
    string memory tokenName,
    string memory tokenSymbol,
    string[2] memory uris, // [basetokenURI, collectionURI]
    uint256[2] memory _collectionSettings, // [maxMintsPerTxn, collectionSize]
    uint256[2] memory _settings //[mintPrice, maxWalletMints]
  ) { 
    erc20Payable = _owner;
  
    payableAddresses = _payables;
    payableFees = _payouts;
    payableAddressCount = _payables.length;

    _baseTokenURI = uris[0];
    _contractURI = uris[1];

    PRICE = _settings[0];
    MAX_WALLET_MINTS = _settings[1];

    // Contract-wide presets
    strictPricing = true;
    _baseTokenExtension = ".json";

    Ownable._transferOwnership(_owner);
    ERC721A._init(tokenName, tokenSymbol, _collectionSettings[0], _collectionSettings[1]);
  }

  uint8 constant public CONTRACT_VERSION = 3;
  string public _contractURI;
  string public _baseTokenURI;
  string public _baseTokenExtension;
  bool public mintingOpen;
  uint256 public MAX_WALLET_MINTS;
  uint256 public PRICE;

  /////////////// Admin Mint Functions
  /**
    * @dev Mints a token to an address with a tokenURI.
    * This is owner only and allows a fee-free drop
    * @param _to address of the future owner of the token
    * @param _qty amount of tokens to drop the owner
    */
    function mintToAdminV2(address _to, uint256 _qty) public onlyTeamOrOwner{
        if(_qty == 0) revert MintZeroQuantity();
        if(currentTokenId() + _qty > collectionSize) revert CapExceeded();
        _safeMint(_to, _qty, true);
    }


  /////////////// PUBLIC MINT FUNCTIONS
  /**
  * @dev Mints tokens to an address in batch.
  * fee may or may not be required*
  * @param _to address of the future owner of the token
  * @param _amount number of tokens to mint
  */
  function mintToMultiple(address _to, uint256 _amount) public payable {
      if(onlyERC20MintingMode) revert OnlyERC20MintingEnabled();
      if(_amount == 0) revert MintZeroQuantity();
      if(_amount > maxBatchSize) revert TransactionCapExceeded();
      if(!mintingOpen) revert PublicMintClosed();
      if(mintingOpen && onlyAllowlistMode) revert PublicMintClosed();
      
      if(!canMintAmount(_to, _amount)) revert ExcessiveOwnedMints();
      if(currentTokenId() + _amount > collectionSize) revert CapExceeded();
      if(!priceIsRight(msg.value, getPrice(_amount))) revert InvalidPayment();
      _safeMint(_to, _amount, false);
  }

  /**
    * @dev Mints tokens to an address in batch using an ERC-20 token for payment
    * fee may or may not be required*
    * @param _to address of the future owner of the token
    * @param _amount number of tokens to mint
    * @param _erc20TokenContract erc-20 token contract to mint with
    */
  function mintToMultipleERC20(address _to, uint256 _amount, address _erc20TokenContract) public payable {
    if(_amount == 0) revert MintZeroQuantity();
    if(_amount > maxBatchSize) revert TransactionCapExceeded();
    if(!mintingOpen) revert PublicMintClosed();
    if(currentTokenId() + _amount > collectionSize) revert CapExceeded();
    if(mintingOpen && onlyAllowlistMode) revert PublicMintClosed();
    
    if(!canMintAmount(_to, _amount)) revert ExcessiveOwnedMints();

    // ERC-20 Specific pre-flight checks
    if(!isApprovedForERC20Payments(_erc20TokenContract)) revert ERC20TokenNoApprove();
    uint256 tokensQtyToTransfer = chargeAmountForERC20(_erc20TokenContract) * _amount;
    IERC20 payableToken = IERC20(_erc20TokenContract);

    if(payableToken.balanceOf(_to) < tokensQtyToTransfer) revert ERC20LowBalance();
    if(payableToken.allowance(_to, address(this)) < tokensQtyToTransfer) revert ERC20LowAllowance();

    bool transferComplete = payableToken.transferFrom(_to, address(this), tokensQtyToTransfer);
    if(!transferComplete) revert ERC20TransferFailed();

    _safeMint(_to, _amount, false);
  }

  function openMinting() public onlyTeamOrOwner {
      mintingOpen = true;
  }

  function stopMinting() public onlyTeamOrOwner {
      mintingOpen = false;
  }


  ///////////// ALLOWLIST MINTING FUNCTIONS
  /**
  * @dev Mints tokens to an address using an allowlist.
  * fee may or may not be required*
  * @param _to address of the future owner of the token
  * @param _amount number of tokens to mint
  * @param _merkleProof merkle proof array
  */
  function mintToMultipleAL(address _to, uint256 _amount, bytes32[] calldata _merkleProof) public payable {
      if(onlyERC20MintingMode) revert OnlyERC20MintingEnabled();
      if(!onlyAllowlistMode || !mintingOpen) revert AllowlistMintClosed();
      if(!isAllowlisted(_to, _merkleProof)) revert AddressNotAllowlisted();
      if(_amount == 0) revert MintZeroQuantity();
      if(_amount > maxBatchSize) revert TransactionCapExceeded();
      if(!canMintAmount(_to, _amount)) revert ExcessiveOwnedMints();
      if(currentTokenId() + _amount > collectionSize) revert CapExceeded();
      if(!priceIsRight(msg.value, getPrice(_amount))) revert InvalidPayment();
      
      _safeMint(_to, _amount, false);
  }

  /**
  * @dev Mints tokens to an address using an allowlist.
  * fee may or may not be required*
  * @param _to address of the future owner of the token
  * @param _amount number of tokens to mint
  * @param _merkleProof merkle proof array
  * @param _erc20TokenContract erc-20 token contract to mint with
  */
  function mintToMultipleERC20AL(address _to, uint256 _amount, bytes32[] calldata _merkleProof, address _erc20TokenContract) public payable {
    if(!onlyAllowlistMode || !mintingOpen) revert AllowlistMintClosed();
    if(!isAllowlisted(_to, _merkleProof)) revert AddressNotAllowlisted();
    if(_amount == 0) revert MintZeroQuantity();
    if(_amount > maxBatchSize) revert TransactionCapExceeded();
    if(!canMintAmount(_to, _amount)) revert ExcessiveOwnedMints();
    if(currentTokenId() + _amount > collectionSize) revert CapExceeded();

    // ERC-20 Specific pre-flight checks
    if(!isApprovedForERC20Payments(_erc20TokenContract)) revert ERC20TokenNoApprove();
    uint256 tokensQtyToTransfer = chargeAmountForERC20(_erc20TokenContract) * _amount;
    IERC20 payableToken = IERC20(_erc20TokenContract);

    if(payableToken.balanceOf(_to) < tokensQtyToTransfer) revert ERC20LowBalance();
    if(payableToken.allowance(_to, address(this)) < tokensQtyToTransfer) revert ERC20LowAllowance();

    bool transferComplete = payableToken.transferFrom(_to, address(this), tokensQtyToTransfer);
    if(!transferComplete) revert ERC20TransferFailed();
    
    _safeMint(_to, _amount, false);
  }

  /**
    * @dev Enable allowlist minting fully by enabling both flags
    * This is a convenience function for the Rampp user
    */
  function openAllowlistMint() public onlyTeamOrOwner {
      enableAllowlistOnlyMode();
      mintingOpen = true;
  }

  /**
    * @dev Close allowlist minting fully by disabling both flags
    * This is a convenience function for the Rampp user
    */
  function closeAllowlistMint() public onlyTeamOrOwner {
      disableAllowlistOnlyMode();
      mintingOpen = false;
  }

  /**
  * @dev Check if wallet over MAX_WALLET_MINTS
  * @param _address address in question to check if minted count exceeds max
  */
  function canMintAmount(address _address, uint256 _amount) public view returns(bool) {
      if(_amount == 0) revert ValueNotZero();
      return (_numberMinted(_address) + _amount) <= MAX_WALLET_MINTS;
  }

  /**
  * @dev Update the maximum amount of tokens that can be minted by a unique wallet
  * @param _newWalletMax the new max of tokens a wallet can mint. Must be >= 1
  */
  function setWalletMax(uint256 _newWalletMax) public onlyTeamOrOwner {
      if(_newWalletMax == 0) revert ValueNotZero();
      MAX_WALLET_MINTS = _newWalletMax;
  }
    
  /**
  * @dev Allows owner to set Max mints per tx
  * @param _newMaxMint maximum amount of tokens allowed to mint per tx. Must be >= 1
  */
  function setMaxMint(uint256 _newMaxMint) public onlyTeamOrOwner {
      if(_newMaxMint == 0) revert ValueNotZero();
      maxBatchSize = _newMaxMint;
  }

  function setPrice(uint256 _feeInWei) public onlyTeamOrOwner {
    PRICE = _feeInWei;
  }

  function getPrice(uint256 _count) public view returns (uint256) {
    return (PRICE * _count);
  }
    
  function contractURI() public view returns (string memory) {
    return _contractURI;
  }
  

  function _baseURI() internal view virtual override returns(string memory) {
    return _baseTokenURI;
  }

  function _baseURIExtension() internal view virtual override returns(string memory) {
    return _baseTokenExtension;
  }

  function baseTokenURI() public view returns(string memory) {
    return _baseTokenURI;
  }

  function setBaseURI(string calldata baseURI) external onlyTeamOrOwner {
    _baseTokenURI = baseURI;
  }

  function setBaseTokenExtension(string calldata baseExtension) external onlyTeamOrOwner {
    _baseTokenExtension = baseExtension;
  }
}