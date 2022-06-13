// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IBoilerplateERC721 is IERC721Enumerable {
    /* External Functions */
    function setBaseURI(string memory _newBaseURI) external;
    function pausePublic(bool _state) external;
    function mint(address token, uint amount, address collection) external payable;
    function batchTransfer(address from, address to, uint256[] calldata tokenIds) external;
    function walletOfOwner(address _owner) external view returns (uint256[] memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}