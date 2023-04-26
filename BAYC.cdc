import NonFungibleToken from "./utility/NonFungibleToken.cdc"
import FlowToken from "./utility/FlowToken.cdc"
import FungibleToken from "./utility/FungibleToken.cdc"

// 1. User mints an NFT publicly with payment
// 2. Admin fulfills metadata (in the form of a Template struct) 
// afterwards mapping from the NFT's serial

pub contract BoredApeYachtClub: NonFungibleToken {

    // for NFT standard
    pub var totalSupply: UInt64

    // custom variables
    pub let apePrice: UFix64
    pub let maxApePurchase: UInt64
    pub var maxApes: UInt64
    pub var saleIsActive: Bool

    // events
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    // paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    pub struct Template {
        // let's assume this is a `cid` for IPFS
        pub let image: String
        pub let attributes: {String: String}

        init(image: String, attributes: {String: String}) {
            self.image = image
            self.attributes = attributes
        }
    }

    // maps serial -> Template
    access(self) let templates: {UInt64: Template}

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64
        pub let serial: UInt64

        pub let name: String
        pub let description: String

        pub fun getTemplate(): Template? {
            return BoredApeYachtClub.templates[self.serial]
        }

        init() {
            self.id = self.uuid
            self.serial = BoredApeYachtClub.totalSupply
            BoredApeYachtClub.totalSupply = BoredApeYachtClub.totalSupply + 1

            self.name = "Bored Ape #".concat(self.id.toString())
            self.description = "By BoredApeYachtClub, with a sprinkle of Jacob Tucker magic."
        }
    }

    pub resource interface CollectionPublic {
        pub fun borrowApeNFT(id: UInt64): &NFT?
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, CollectionPublic {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("This NFT does not exist in this Collection.")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @NFT
            let id: UInt64 = token.id
            self.ownedNFTs[id] <-! token
            emit Deposit(id: id, to: self.owner?.address)
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowApeNFT(id: UInt64): &NFT? {
            let token = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
            return token as! &NFT?
        }

        init() {
            self.ownedNFTs <- {}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    pub resource Owner {
        pub fun flipSaleState() {
            BoredApeYachtClub.saleIsActive = !BoredApeYachtClub.saleIsActive
        }

        pub fun fulfillMetadata(templateId: UInt64, image: String, attributes: {String: String}) {
            BoredApeYachtClub.templates[templateId] = Template(image: image, attributes: attributes)
        }
    }

    pub fun mintApe(
        numberOfTokens: UInt64, 
        payment: @FlowToken.Vault, 
        recipientVault: &Collection{NonFungibleToken.Receiver}
    ) {
        pre {
            BoredApeYachtClub.saleIsActive: "Sale must be active to mint Ape"
            numberOfTokens <= BoredApeYachtClub.maxApePurchase: "Can only mint 20 tokens at a time"
            BoredApeYachtClub.totalSupply + numberOfTokens <= BoredApeYachtClub.maxApes: "Purchase would exceed max supply of Apes"
            BoredApeYachtClub.apePrice * UFix64(numberOfTokens) == payment.balance: "$FLOW value sent is not correct"
        }

        var i: UInt64 = 0
        while i < numberOfTokens {
            recipientVault.deposit(token: <- create NFT())
            i = i + 1
        }

        // deposit the payment to the contract owner
        let ownerVault = BoredApeYachtClub.account.getCapability(/public/flowTokenReceiver)
                            .borrow<&FlowToken.Vault{FungibleToken.Receiver}>()
                            ?? panic("Could not get the Flow Token Vault from the Owner of this contract.")
        ownerVault.deposit(from: <- payment)
    }

    init(maxNftSupply: UInt64) {
        self.totalSupply = 0
        self.templates = {}
        
        self.apePrice = 0.08 // $FLOW
        self.maxApePurchase = 20
        self.maxApes = maxNftSupply
        self.saleIsActive = false

        self.CollectionStoragePath = /storage/BAYCCollection
        self.CollectionPublicPath = /public/BAYCCollection

        self.account.save(<- create Owner(), to: /storage/BAYCOwner)
    }
}
 