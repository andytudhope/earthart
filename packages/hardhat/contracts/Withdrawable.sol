// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./Teams.sol";

error PayablePayoutMisMatch();
error PayoutsNot100();
error ERC20TokenNotApproved();
error ERC20InsufficientBalance();
error CannotBeNullAddress();
error ValueCannotBeZero();
error NoStateChange();

/**
* @dev These functions deal with verification of Merkle Trees proofs.
*
* The proofs can be generated using the JavaScript library
* https://github.com/miguelmota/merkletreejs[merkletreejs].
* Note: the hashing algorithm should be keccak256 and pair sorting should be enabled.
*
*
* WARNING: You should avoid using leaf values that are 64 bytes long prior to
* hashing, or use a hash function other than keccak256 for hashing leaves.
* This is because the concatenation of a sorted pair of internal nodes in
* the merkle tree could be reinterpreted as a leaf value.
*/
library MerkleProof {
    /**
    * @dev Returns true if a 'leaf' can be proved to be a part of a Merkle tree
    * defined by 'root'. For this, a 'proof' must be provided, containing
    * sibling hashes on the branch from the leaf to the root of the tree. Each
    * pair of leaves and each pair of pre-images are assumed to be sorted.
    */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
    * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
    * from 'leaf' using 'proof'. A 'proof' is valid if and only if the rebuilt
    * hash matches the root of the tree. When processing the proof, the pairs
    * of leafs & pre-images are assumed to be sorted.
    *
    * _Available since v4.4._
    */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = _efficientHash(computedHash, proofElement);
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = _efficientHash(proofElement, computedHash);
            }
        }
        return computedHash;
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

abstract contract Allowlist is Teams {
    bytes32 public merkleRoot;
    bool public onlyAllowlistMode;

    /**
     * @dev Update merkle root to reflect changes in Allowlist
     * @param _newMerkleRoot new merkle root to reflect most recent Allowlist
     */
    function updateMerkleRoot(bytes32 _newMerkleRoot) public onlyTeamOrOwner {
      if(_newMerkleRoot == merkleRoot) revert NoStateChange();
      merkleRoot = _newMerkleRoot;
    }

    /**
     * @dev Check the proof of an address if valid for merkle root
     * @param _to address to check for proof
     * @param _merkleProof Proof of the address to validate against root and leaf
     */
    function isAllowlisted(address _to, bytes32[] calldata _merkleProof) public view returns(bool) {
      if(merkleRoot == 0) revert ValueCannotBeZero();
      bytes32 leaf = keccak256(abi.encodePacked(_to));

      return MerkleProof.verify(_merkleProof, merkleRoot, leaf);
    }

    
    function enableAllowlistOnlyMode() public onlyTeamOrOwner {
      onlyAllowlistMode = true;
    }

    function disableAllowlistOnlyMode() public onlyTeamOrOwner {
        onlyAllowlistMode = false;
    }
}

interface IERC20 {
  function allowance(address owner, address spender) external view returns (uint256);
  function transfer(address _to, uint256 _amount) external returns (bool);
  function balanceOf(address account) external view returns (uint256);
  function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// This abstract allows the contract to be able to mint and ingest ERC-20 payments for mints.
// ERC-20 Payouts are limited to a single payout address. This feature 
// will charge a small flat fee in native currency that is not subject to regular rev sharing.
// This contract also covers the normal functionality of accepting native base currency rev-sharing
abstract contract Withdrawable is Teams {
  struct acceptedERC20 {
    bool isActive;
    uint256 chargeAmount;
  }

  
  mapping(address => acceptedERC20) private allowedTokenContracts;
  address[] public payableAddresses;
  address public erc20Payable;
  uint256[] public payableFees;
  uint256 public payableAddressCount;
  bool public onlyERC20MintingMode;
  
  function resetPayables(address[] memory _newPayables, uint256[] memory _newPayouts) public onlyTeamOrOwner {
    if(_newPayables.length != _newPayouts.length) revert PayablePayoutMisMatch();

    uint sum;
    for(uint i=0; i < _newPayouts.length; i++ ) {
        sum += _newPayouts[i];
    }
    if(sum != 100) revert PayoutsNot100();

    payableAddresses = _newPayables;
    payableFees = _newPayouts;
    payableAddressCount = _newPayables.length;
  }

  function withdrawAll() public onlyTeamOrOwner {
      if(address(this).balance == 0) revert ValueCannotBeZero();
      _withdrawAll(address(this).balance);
  }

  function _withdrawAll(uint256 balance) private {
      for(uint i=0; i < payableAddressCount; i++ ) {
          _widthdraw(
              payableAddresses[i],
              (balance * payableFees[i]) / 100
          );
      }
  }
  
  function _widthdraw(address _address, uint256 _amount) private {
      (bool success, ) = _address.call{value: _amount}("");
      require(success, "Transfer failed.");
  }

  /**
  * @dev Allow contract owner to withdraw ERC-20 balance from contract
  * in the event ERC-20 tokens are paid to the contract for mints.
  * @param _tokenContract contract of ERC-20 token to withdraw
  * @param _amountToWithdraw balance to withdraw according to balanceOf of ERC-20 token in wei
  */
  function withdrawERC20(address _tokenContract, uint256 _amountToWithdraw) public onlyTeamOrOwner {
    if(_amountToWithdraw == 0) revert ValueCannotBeZero();
    IERC20 tokenContract = IERC20(_tokenContract);
    if(tokenContract.balanceOf(address(this)) < _amountToWithdraw) revert ERC20InsufficientBalance();
    tokenContract.transfer(erc20Payable, _amountToWithdraw); // Payout ERC-20 tokens to recipient
  }

  /**
  * @dev check if an ERC-20 contract is a valid payable contract for executing a mint.
  * @param _erc20TokenContract address of ERC-20 contract in question
  */
  function isApprovedForERC20Payments(address _erc20TokenContract) public view returns(bool) {
    return allowedTokenContracts[_erc20TokenContract].isActive == true;
  }

  /**
  * @dev get the value of tokens to transfer for user of an ERC-20
  * @param _erc20TokenContract address of ERC-20 contract in question
  */
  function chargeAmountForERC20(address _erc20TokenContract) public view returns(uint256) {
    if(!isApprovedForERC20Payments(_erc20TokenContract)) revert ERC20TokenNotApproved();
    return allowedTokenContracts[_erc20TokenContract].chargeAmount;
  }

  /**
  * @dev Explicity sets and ERC-20 contract as an allowed payment method for minting
  * @param _erc20TokenContract address of ERC-20 contract in question
  * @param _isActive default status of if contract should be allowed to accept payments
  * @param _chargeAmountInTokens fee (in tokens) to charge for mints for this specific ERC-20 token
  */
  function addOrUpdateERC20ContractAsPayment(address _erc20TokenContract, bool _isActive, uint256 _chargeAmountInTokens) public onlyTeamOrOwner {
    allowedTokenContracts[_erc20TokenContract].isActive = _isActive;
    allowedTokenContracts[_erc20TokenContract].chargeAmount = _chargeAmountInTokens;
  }

  /**
  * @dev Add an ERC-20 contract as being a valid payment method. If passed a contract which has not been added
  * it will assume the default value of zero. This should not be used to create new payment tokens.
  * @param _erc20TokenContract address of ERC-20 contract in question
  */
  function enableERC20ContractAsPayment(address _erc20TokenContract) public onlyTeamOrOwner {
    allowedTokenContracts[_erc20TokenContract].isActive = true;
  }

  /**
  * @dev Disable an ERC-20 contract as being a valid payment method. If passed a contract which has not been added
  * it will assume the default value of zero. This should not be used to create new payment tokens.
  * @param _erc20TokenContract address of ERC-20 contract in question
  */
  function disableERC20ContractAsPayment(address _erc20TokenContract) public onlyTeamOrOwner {
    allowedTokenContracts[_erc20TokenContract].isActive = false;
  }

  /**
  * @dev Enable only ERC-20 payments for minting on this contract
  */
  function enableERC20OnlyMinting() public onlyTeamOrOwner {
    onlyERC20MintingMode = true;
  }

  /**
  * @dev Disable only ERC-20 payments for minting on this contract
  */
  function disableERC20OnlyMinting() public onlyTeamOrOwner {
    onlyERC20MintingMode = false;
  }

  /**
  * @dev Set the payout of the ERC-20 token payout to a specific address
  * @param _newErc20Payable new payout addresses of ERC-20 tokens
  */
  function setERC20PayableAddress(address _newErc20Payable) public onlyTeamOrOwner {
    if(_newErc20Payable == address(0)) revert CannotBeNullAddress();
    if(_newErc20Payable == erc20Payable) revert NoStateChange();
    erc20Payable = _newErc20Payable;
  }
}