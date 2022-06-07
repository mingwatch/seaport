// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
// prettier-ignore
import { BaseConsiderationTest } from "../utils/BaseConsiderationTest.sol";

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import { ConduitItemType } from "../../../contracts/conduit/lib/ConduitEnums.sol";

import { TransferHelper } from "../../../contracts/helper/TransferHelper.sol";

import { TransferHelperItem } from "../../../contracts/helper/TransferHelperStructs.sol";

import { TestERC20 } from "../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";

contract TransferHelperTest is BaseOrderTest {
    TransferHelper transferHelper;
    TestERC20 testErc20;

    function setUp() public override {
        super.setUp();
        transferHelper = new TransferHelper(address(conduitController));

        address thisAddress = address(this);
        token1.mint(thisAddress, 20);
        test721_1.mint(thisAddress, 1);
        test1155_1.mint(thisAddress, 1, 20);
        _setApprovals(thisAddress);
    }

    function _setApprovals(address _owner) internal override {
        super._setApprovals(_owner);
        vm.startPrank(_owner);
        for (uint256 i = 0; i < erc20s.length; i++) {
            erc20s[i].approve(address(transferHelper), MAX_INT);
        }
        for (uint256 i = 0; i < erc1155s.length; i++) {
            erc1155s[i].setApprovalForAll(address(transferHelper), true);
        }
        for (uint256 i = 0; i < erc721s.length; i++) {
            erc721s[i].setApprovalForAll(address(transferHelper), true);
        }
        vm.stopPrank();
        emit log_named_address(
            "Owner proxy approved for all tokens from",
            _owner
        );
        emit log_named_address(
            "Consideration approved for all tokens from",
            _owner
        );
    }

    function balanceOfTransferItemForAddress(
        TransferHelperItem memory item,
        address addr
    ) public returns (uint256) {
        if (item.itemType == ConduitItemType.ERC20) {
            return TestERC20(item.token).balanceOf(addr);
        } else if (item.itemType == ConduitItemType.ERC721) {
            return
                TestERC721(item.token).ownerOf(item.tokenIdentifier) == addr
                    ? 1
                    : 0;
        } else if (item.itemType == ConduitItemType.ERC1155) {
            return
                TestERC1155(item.token).balanceOf(addr, item.tokenIdentifier);
        }
        revert();
    }

    function balanceOfTransferItemForFromTo(
        TransferHelperItem memory item,
        address from,
        address to
    ) public returns (uint256 fromBalance, uint256 toBalance) {
        return (
            balanceOfTransferItemForAddress(item, from),
            balanceOfTransferItemForAddress(item, to)
        );
    }

    function testBulkTransferERC20() public {
        TransferHelperItem[] memory items = new TransferHelperItem[](1);
        uint256 amount = 20;
        items[0] = TransferHelperItem(
            ConduitItemType.ERC20,
            address(token1),
            1,
            amount
        );
        address from = address(this);
        address to = address(1);

        (
            uint256 fromBalanceBeforeTransfer,
            uint256 toBalanceBeforeTransfer
        ) = balanceOfTransferItemForFromTo(items[0], from, to);

        transferHelper.bulkTransfer(items, to, bytes32(0));

        (
            uint256 fromBalanceAfterTransfer,
            uint256 toBalanceAfterTransfer
        ) = balanceOfTransferItemForFromTo(items[0], from, to);
        // Check final balances
        assertEq(fromBalanceAfterTransfer, fromBalanceBeforeTransfer - amount);
        assertEq(toBalanceAfterTransfer, toBalanceBeforeTransfer + amount);
    }

    function testBulkTransferERC721() public {
        TransferHelperItem[] memory items = new TransferHelperItem[](1);
        uint256 amount = 1;
        items[0] = TransferHelperItem(
            ConduitItemType.ERC721,
            address(test721_1),
            1,
            1
        );
        address from = address(this);
        address to = address(1);

        // Get initial balances
        // TODO create helper fn that takes in an arbitrary token ID
        // and list of addresses and returns a list of balances
        address ownerBeforeTransfer = test721_1.ownerOf(1);
        assertEq(ownerBeforeTransfer, from);

        transferHelper.bulkTransfer(items, to, bytes32(0));

        // Check final balances
        address ownerAfterTransfer = test721_1.ownerOf(1);
        assertEq(ownerAfterTransfer, to);
    }

    function testBulkTransferERC1155() public {
        TransferHelperItem[] memory items = new TransferHelperItem[](1);
        uint256 amount = 20;
        items[0] = TransferHelperItem(
            ConduitItemType.ERC1155,
            address(test1155_1),
            1,
            amount
        );
        address from = address(this);
        address to = address(1);
        uint256 tokenId = 1;

        // Get initial balances
        // TODO create helper fn that takes in an arbitrary token ID
        // and list of addresses and returns a list of balances
        uint256 fromBalanceBeforeTransfer = test1155_1.balanceOf(from, tokenId);
        uint256 toBalanceBeforeTransfer = test1155_1.balanceOf(to, tokenId);

        transferHelper.bulkTransfer(items, to, bytes32(0));

        // Check final balances
        assertEq(
            test1155_1.balanceOf(from, tokenId),
            fromBalanceBeforeTransfer - amount
        );
        assertEq(
            test1155_1.balanceOf(to, tokenId),
            toBalanceBeforeTransfer + amount
        );
    }
}
