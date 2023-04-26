import BoredApeYachtClub from "../BAYC.cdc"

pub fun main(user: Address, id: UInt64): Metadata {
  let collection = getAccount(user).getCapability(BoredApeYachtClub.CollectionPublicPath)
                    .borrow<&BoredApeYachtClub.Collection{BoredApeYachtClub.CollectionPublic}>()
                    ?? panic("User does not have a Collection set up.")
  let nft = collection.borrowApeNFT(id: id)!
  return Metadata(nft.name, nft.description, nft.getTemplate()!.image, nft.getTemplate()!.attributes)
}

pub struct Metadata {
  pub let name: String
  pub let description: String
  pub let image: String
  pub let attributes: {String: String}

  init(_ n: String, _ d: String, _ i: String, _ a: {String: String}) {
    self.name = n
    self.description = d
    self.image = i
    self.attributes = a
  }
}

