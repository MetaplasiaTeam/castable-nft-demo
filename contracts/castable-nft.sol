// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "https://github.com/MetaplasiaTeam/castable-nft/blob/main/constracts/ERC721/IERC721Castable.sol";
// npm install @openzeppelin-contracts required



contract CastableNFT is ERC721, Ownable,IERC721Castable {
    uint256 public tokenCounter;
    uint256 public  minMintValue;

    address[] private _hasBeenCastERC20TokenAddrs;
    address[] private _hasBeenCastERC721TokenAddrs;


    // Mapping from tokenId to casting type(1.Ethereum,2.ERC20,3.ERC721);
    mapping(uint256 => uint256) private _tokenMintTyp;
    // Mapping from tokenId to uri
    mapping(uint256 => string) private _tokenURIs;
    // Mapping from tokenId to burnBlockNum
    mapping(uint256 => uint256) private _tokenBurnBlockNum;
    // Mapping from tokenId to casting value(wei);
    mapping(uint256 => uint256) private _tokenValues;
    // Mapping from tokenId to erc20 token value;
    mapping(uint256 => mapping(address => uint256)) private _erc20TokenValues;
    // Mapping from tokenId to erc721 token id;
    mapping(uint256 => mapping(address => uint256)) private _erc721TokenIds;



    constructor()  ERC721 ("Castable NFT", "CASTABLE") {
        tokenCounter = 0;
    }

    modifier existToken(uint256 _tokenId) {
        require(_exists(_tokenId), "Nonexistent token!");
        _;
    }

    function setMinMintValue(uint256 _value) public onlyOwner {
        minMintValue = _value;
    }

    function tokenURI(uint256 _tokenId) public view override existToken(_tokenId) returns (string memory) {
        return _tokenURIs[_tokenId];
    }

    function tokenValue(uint256 _tokenId) external view existToken(_tokenId) returns (address addr, uint256 value) {
        if (_tokenMintTyp[_tokenId] == 1) {
            addr = address(0);
            value = _tokenValues[_tokenId];
        } else if (_tokenMintTyp[_tokenId] == 2) {
            for (uint256 i = 0; i < _hasBeenCastERC20TokenAddrs.length; i++) {
                addr = _hasBeenCastERC20TokenAddrs[i];
                value = _erc20TokenValues[_tokenId][addr];
                if (value != 0) {
                    break;
                }
            }

        } else {
            for (uint256 i = 0; i < _hasBeenCastERC721TokenAddrs.length; i++) {
                addr = _hasBeenCastERC721TokenAddrs[i];
                value = _erc721TokenIds[_tokenId][addr];
                if (value != 0) {
                    break;
                }
            }
        }
    }

    function tokenBurnBlockNum(uint256 _tokenId) external view existToken(_tokenId) returns (uint256) {
        return _tokenBurnBlockNum[_tokenId];
    }

    function _isERC20TokenHasBeenCast(address _addr) private view returns (bool) {
        for (uint256 i = 0; i < _hasBeenCastERC20TokenAddrs.length; i++) {
            if (_hasBeenCastERC20TokenAddrs[i] == _addr) {
                return true;
            }
        }
        return false;
    }

    function _isERC721TokenHasBeenCast(address _addr) private view returns (bool) {
        for (uint256 i = 0; i < _hasBeenCastERC721TokenAddrs.length; i++) {
            if (_hasBeenCastERC721TokenAddrs[i] == _addr) {
                return true;
            }
        }
        return false;
    }

    function _createCollectible(string memory _uri) private returns (uint256)  {
        uint256 newItemId = tokenCounter;
        _safeMint(msg.sender, newItemId);
        _tokenURIs[newItemId] = _uri;
        tokenCounter ++;
        return newItemId;
    }



    /**
     * @dev create a collection using the specified uri.
     */
    function createCollectible(string memory _uri,uint256 _burnBlockNum) public payable returns (uint256) {
        require(msg.value >= minMintValue, "Less than the minimum casting value");
        uint256 newItemId = _createCollectible(_uri);
        _tokenValues[newItemId] = msg.value;
        _tokenBurnBlockNum[newItemId] = _burnBlockNum;
        _tokenMintTyp[newItemId] = 1;
        return newItemId;
    }

    /**
     * @dev create multiple collections with the same uri
     */
    function createMultipleCollectibles(string memory _uri, uint256 count,uint256 _burnBlockNum) public payable returns (uint256[] memory) {
        require(msg.value >= minMintValue, "Less than the minimum casting value");
        uint256[] memory ids = new uint[](count);
        uint256 castingValue = msg.value / count;
        for (uint256 i = 0; i < count; i++) {
            uint256 newItemId = _createCollectible(_uri);
            ids[i] = newItemId;
            _tokenValues[newItemId] = castingValue;
            _tokenBurnBlockNum[newItemId] = _burnBlockNum;
            _tokenMintTyp[newItemId] = 1;
        }
        return ids;
    }


    /**
     * @dev create multiple collectibles specified casting value and uri.
     *
     * Requirements:
     *
     * payable value needs to be greater than or equal to the sum of `_values`.
     *
     */
    function createMultipleCollectiblesCustom(string[] memory _uris, uint256[] memory _values,uint256 _burnBlockNum) public payable returns (uint256[] memory) {
        require(msg.value >= minMintValue, "Less than the minimum casting value");
        require(_uris.length == _values.length, "Inconsistent length");
        uint256 totalValue;
        for (uint256 i = 0; i < _values.length; i++) {
            totalValue += _values[i];
        }

        require(msg.value >= totalValue, "Payable value must greater than _values!");


        uint256[] memory ids = new uint[](_uris.length);
        for (uint256 i = 0; i < _uris.length; i++) {
            uint256 newItemId = _createCollectible(_uris[i]);
            ids[i] = newItemId;
            _tokenValues[newItemId] = _values[i];
            _tokenBurnBlockNum[newItemId] = _burnBlockNum;
            _tokenMintTyp[newItemId] = 1;
        }
        return ids;
    }



    /**
    * @dev create a collection minted using erc20 tokens.
     *
     * Requirements:
     *
     * senders need to sets `_castingValue` amount as the allowance of this contract 
     * in ERC20 token in advance.
     *
     */
    function createCollectibleByERC20(address _addr, uint256 _value, string memory _uri,uint256 _burnBlockNum) public returns (uint256) {
        require(_value > 0, "Value must be greater than 0");
        IERC20 erc20Token = IERC20(_addr);
        require(erc20Token.allowance(msg.sender, address(this)) >= _value, "Insufficient allowance!");
        require(erc20Token.transferFrom(msg.sender, address(this), _value), "Transfer failed!");

        // check if it has been cast before
        if (_isERC20TokenHasBeenCast(_addr) == false) {
            _hasBeenCastERC20TokenAddrs.push(_addr);
        }
        uint256 newItemId = _createCollectible(_uri);
        _erc20TokenValues[newItemId][_addr] = _value;
        _tokenBurnBlockNum[newItemId] = _burnBlockNum;
        _tokenMintTyp[newItemId] = 2;
        return newItemId;
    }

    /**
    * @dev create multiple collectibles minted using erc20 tokens.
     * each collectible has the same uri and the cast value is equally distributed.
     *
     * Requirements:
     *
     * senders need to sets `_castingValue` amount as the allowance of this contract
     * in ERC20 token in advance.
     *
     */
    function createMultipleCollectiblesByERC20(address _addr, string memory _uri, uint256 _value, uint256 count,uint256 _burnBlockNum) public returns (uint256[] memory) {
        require(_value > 0, "Value must be greater than 0");
        IERC20 erc20Token = IERC20(_addr);
        require(erc20Token.allowance(msg.sender, address(this)) >= _value, "Insufficient allowance!");
        require(erc20Token.transferFrom(msg.sender, address(this), _value), "Transfer failed!");

        // check if it has been cast before
        if (_isERC20TokenHasBeenCast(_addr) == false) {
            _hasBeenCastERC20TokenAddrs.push(_addr);
        }

        uint256[] memory ids = new uint[](count);
        uint256 aveCastingValue = _value / count;
        for (uint256 i = 0; i < count; i++) {
            uint256 newItemId = _createCollectible(_uri);
            _erc20TokenValues[newItemId][_addr] = aveCastingValue;
            _tokenBurnBlockNum[newItemId] = _burnBlockNum;
            _tokenMintTyp[newItemId] = 2;
            ids[i] = newItemId;
        }
        return ids;
    }

    /**
     * @dev create multiple collectibles minted using erc20 tokens.
     * each collectible has specified uri and casting value.
     *
     * Requirements:
     *
     * senders need to sets the sum of `_values` as the allowance to this contract
     * in ERC20 token in advance.
     *
     */
    function createMultipleCollectiblesByERC20Custom(address _addr, string[] memory _uris, uint256[] memory _values,uint256 _burnBlockNum) public returns (uint256[] memory) {
        require(_uris.length == _values.length, "Inconsistent length");
        uint256 totalValue;
        for (uint256 i = 0; i < _values.length; i++) {
            totalValue += _values[i];
        }
        require(totalValue > 0, "TotalValue must be greater than 0");

        IERC20 erc20Token = IERC20(_addr);
        require(erc20Token.allowance(msg.sender, address(this)) >= totalValue, "Insufficient allowance!");
        require(erc20Token.transferFrom(msg.sender, address(this), totalValue), "Transfer failed!");

        // check if it has been cast before
        if (_isERC20TokenHasBeenCast(_addr) == false) {
            _hasBeenCastERC20TokenAddrs.push(_addr);
        }

        uint256[] memory ids = new uint[](_uris.length);
        for (uint256 i = 0; i < _uris.length; i++) {
            uint256 newItemId = _createCollectible(_uris[i]);
            _erc20TokenValues[newItemId][_addr] = _values[i];
            _tokenBurnBlockNum[newItemId] = _burnBlockNum;
            _tokenMintTyp[newItemId] = 2;
            ids[i] = newItemId;
        }
        return ids;
    }



    /**
    * @dev create a collection minted using ERC721 tokens.
     *
     */
    function createCollectibleByERC721(address _addr, uint256 _id, string memory _uri,uint256 _burnBlockNum) public returns (uint256) {
        IERC721 erc721Token = IERC721(_addr);

        require(erc721Token.getApproved(_id) == address(this), "Contract is not approved for this erc721 token");
        erc721Token.transferFrom(msg.sender, address(this), _id);

        // check if it has been cast before
        if (_isERC721TokenHasBeenCast(_addr) == false) {
            _hasBeenCastERC721TokenAddrs.push(_addr);
        }
        uint256 newItemId = _createCollectible(_uri);
        // add 1 here so that don't get cast if id = 0;
        _erc721TokenIds[newItemId][_addr] = _id + 1;
        _tokenBurnBlockNum[newItemId] = _burnBlockNum;
        _tokenMintTyp[newItemId] = 3;
        return newItemId;
    }

    /**
    * @dev create multiple collectibles minted using ERC721 tokens.
     *
     */
    function createMultipleCollectiblesByERC721(address _addr, string[] memory _uris, uint256[] memory _ids,uint256 _burnBlockNum) public returns (uint256[] memory) {
        // check if it has been cast before
        if (_isERC721TokenHasBeenCast(_addr) == false) {
            _hasBeenCastERC721TokenAddrs.push(_addr);
        }

        IERC721 erc721Token = IERC721(_addr);
        uint256[] memory ids = new uint[](_uris.length);
        for (uint256 i = 0; i < _uris.length; i++) {
            require(erc721Token.getApproved(_ids[i]) == address(this), "Contract is not approved for this erc721 token");
            erc721Token.transferFrom(msg.sender, address(this), _ids[i]);

            uint256 newItemId = _createCollectible(_uris[i]);
            _erc721TokenIds[newItemId][_addr] = _ids[i] + 1;
            _tokenBurnBlockNum[newItemId] = _burnBlockNum;
            _tokenMintTyp[newItemId] = 3;
            ids[i] = newItemId;
        }

        return ids;
    }


    /**
     * @dev burn collectibles returns the casting value(Ethereum,ERC720,ERC721 token value).
     */
    function burnCollectible(uint256 _tokenId) existToken(_tokenId) public {
        require(_isApprovedOrOwner(msg.sender, _tokenId), "ERC721: transfer caller is not owner nor approved");
        require(block.number >= _tokenBurnBlockNum[_tokenId], "It can be burned only when it reaches the designated block");
        _burn(_tokenId);

        if (_tokenMintTyp[_tokenId] == 1) {
            (bool sent,) = msg.sender.call{value : _tokenValues[_tokenId]}("");
            require(sent, "Failed to send Ether");
        } else if (_tokenMintTyp[_tokenId] == 2) {
            for (uint256 i = 0; i < _hasBeenCastERC20TokenAddrs.length; i++) {
                address erc20TokenAddr = _hasBeenCastERC20TokenAddrs[i];
                uint256 erc20TokenValue = _erc20TokenValues[_tokenId][erc20TokenAddr];
                if (erc20TokenValue != 0) {
                    IERC20 erc20Token = IERC20(erc20TokenAddr);
                    erc20Token.transfer(msg.sender, erc20TokenValue);
                }
            }

        } else {
            for (uint256 i = 0; i < _hasBeenCastERC721TokenAddrs.length; i++) {
                address erc721TokenAddr = _hasBeenCastERC721TokenAddrs[i];
                uint256 erc721Id = _erc721TokenIds[_tokenId][erc721TokenAddr];
                if (erc721Id != 0) {
                    IERC721 erc721Token = IERC721(erc721TokenAddr);
                    erc721Token.safeTransferFrom(address(this), msg.sender, erc721Id - 1);
                }
            }
        }
    }
}
