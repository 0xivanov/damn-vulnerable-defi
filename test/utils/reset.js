const { ethers } = require('hardhat');

module.exports = {
  resetAccounts: async () => {
    let signers = await ethers.getSigners()
    let amount = ethers.utils.parseEther("100000000");
    const amountHex = amount.toHexString().replace("0x0", "0x");
    for (const signer of signers) {
      await network.provider.send("hardhat_setBalance", [
        signer.address,
        amountHex,
      ]);
    }
  }
}