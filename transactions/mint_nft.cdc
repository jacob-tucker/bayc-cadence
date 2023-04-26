import BoredApeYachtClub from "../BAYC.cdc"
import NonFungibleToken from "../utility/NonFungibleToken.cdc"
import FlowToken from "../utility/FlowToken.cdc"

transaction(numberOfApes: UInt64, price: UFix64) {

  let RecipientVault: &BoredApeYachtClub.Collection{NonFungibleToken.Receiver}
  let FlowTokenVault: &FlowToken.Vault

  prepare(signer: AuthAccount) {
    if signer.borrow<&BoredApeYachtClub.Collection>(from: BoredApeYachtClub.CollectionStoragePath) == nil {
      signer.save(<- BoredApeYachtClub.createEmptyCollection(), to: BoredApeYachtClub.CollectionStoragePath)
      signer.link<&BoredApeYachtClub.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, BoredApeYachtClub.CollectionPublic}>(BoredApeYachtClub.CollectionPublicPath, target: BoredApeYachtClub.CollectionStoragePath)
    }
    self.RecipientVault = signer.getCapability(BoredApeYachtClub.CollectionPublicPath)
                            .borrow<&BoredApeYachtClub.Collection{NonFungibleToken.Receiver}>()!
    
    self.FlowTokenVault = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)!
  }

  execute {
    let payment <- self.FlowTokenVault.withdraw(amount: price) as! @FlowToken.Vault
    BoredApeYachtClub.mintApe(numberOfTokens: numberOfApes, payment: <- payment, recipientVault: self.RecipientVault)
  }
}
