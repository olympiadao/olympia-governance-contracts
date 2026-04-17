// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OlympiaDAOGovernor} from "../../src/OlympiaDAOGovernor.sol";
import {OlympiaExecutor} from "../../src/OlympiaExecutor.sol";
import {OlympiaDAOMemberNFT} from "../../src/OlympiaDAOMemberNFT.sol";
import {ECFPRegistry} from "../../src/ECFPRegistry.sol";
import {MembershipVerifier} from "../../src/nft/MembershipVerifier.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title SeedConfig
/// @notice Shared constants, addresses, proposal content and helpers for the Olympia DAO
///         Mordor seeding scripts. All proposal text is public-facing and professional.
/// @dev All scripts inherit this contract. ACME_ADDRESS is read from .env.seed at
///      runtime since it is a user-supplied account  --  everything else is hardcoded here.
abstract contract SeedConfig {
    // =========================================================================
    // Mordor demo_v0.4  --  deployed contract addresses (pending deployment)
    // Run PrecomputeAddresses.s.sol to compute addresses before deploying.
    // Update these constants after deployment.
    // =========================================================================

    OlympiaDAOGovernor internal constant GOVERNOR =
        OlympiaDAOGovernor(payable(0xe763f13cC89292C4F279BEF2aD54F1E89A3a87d3));

    TimelockController internal constant TIMELOCK =
        TimelockController(payable(0x3d19fEfB093Abad60421B89CF48f4569aaae39b6));

    OlympiaExecutor internal constant EXECUTOR =
        OlympiaExecutor(payable(0x292eBe07d11850Dfc94Cbf9c72C3A054d23cAB54));

    OlympiaDAOMemberNFT internal constant MEMBER_NFT =
        OlympiaDAOMemberNFT(0xb4D45A498994C89553A9c923c6b85F7623C0843e);

    MembershipVerifier internal constant VERIFIER =
        MembershipVerifier(0xb6274251Fb8F1D865A0B62bba9fF31c1bfEdccE6);

    ECFPRegistry internal constant REGISTRY =
        ECFPRegistry(0xe2b437284B0fc7A1064Afd1f60686c7cEAa7343a);

    // =========================================================================
    // ECFP identifiers (bytes32 slugs)  --  Wave 1
    // =========================================================================

    bytes32 internal constant ECFP_ID_P1 = keccak256("ECFP-001-GO-RUNTIME-MODERNIZATION");
    bytes32 internal constant ECFP_ID_P2 = keccak256("ECFP-002-CRYPTO-CVE-HARDENING");
    bytes32 internal constant ECFP_ID_P3 = keccak256("ECFP-003-DEPENDENCY-PROTOCOL-SECURITY");
    bytes32 internal constant ECFP_ID_P4 = keccak256("ECFP-004-P2P-RLP-SECURITY");

    // Wave 2
    bytes32 internal constant ECFP_ID_P5 = keccak256("ECFP-005-ETC-CONSENSUS-UNIT-TESTS");
    bytes32 internal constant ECFP_ID_P6 = keccak256("ECFP-006-LIVE-RPC-VECTORS-HYGIENE");

    // =========================================================================
    // Metadata CIDs (bytes32  --  keccak of IPFS placeholder string for testnet)
    // Replace with real IPFS CIDs before mainnet use.
    // =========================================================================

    bytes32 internal constant META_P1 = keccak256("ipfs://QmMockOlympiaSeed-ECFP001-GoRuntime");
    bytes32 internal constant META_P2 = keccak256("ipfs://QmMockOlympiaSeed-ECFP002-CryptoHardening");
    bytes32 internal constant META_P3 = keccak256("ipfs://QmMockOlympiaSeed-ECFP003-DependencySecurity");
    bytes32 internal constant META_P4 = keccak256("ipfs://QmMockOlympiaSeed-ECFP004-P2PSecurity");
    bytes32 internal constant META_P5 = keccak256("ipfs://QmMockOlympiaSeed-ECFP005-ConsensusTests");
    bytes32 internal constant META_P6 = keccak256("ipfs://QmMockOlympiaSeed-ECFP006-LiveRPCHygiene");

    // =========================================================================
    // Submission bond (demo_v0.4) -- must match ECFPRegistry constructor arg
    // ACME account must be funded with (6 × SUBMISSION_BOND) + gas before running
    // scripts 02 and 07.
    // =========================================================================

    uint256 internal constant SUBMISSION_BOND = 1 ether;

    // =========================================================================
    // Treasury disbursement amounts
    //
    // Pricing basis: Senior Blockchain Engineer (Go, cryptography, EVM)
    // Market rate:   $200 USD/hr (contract basis)
    // ETC spot:      $8.52 USD at time of proposal (2026-04-08)
    // =========================================================================

    uint256 internal constant AMOUNT_P1 = 1_200 ether; //  60 hrs × $200 = $12,000 ÷ $8.52 ≈ 1,408 → rounded 1,200
    uint256 internal constant AMOUNT_P2 = 1_600 ether; //  80 hrs × $200 = $16,000 ÷ $8.52 ≈ 1,878 → rounded 1,600
    uint256 internal constant AMOUNT_P3 = 1_400 ether; //  70 hrs × $200 = $14,000 ÷ $8.52 ≈ 1,643 → rounded 1,400
    uint256 internal constant AMOUNT_P4 = 2_200 ether; // 110 hrs × $200 = $22,000 ÷ $8.52 ≈ 2,582 → rounded 2,200
    uint256 internal constant AMOUNT_P5 = 1_600 ether; //  80 hrs × $200 = $16,000 ÷ $8.52 ≈ 1,878 → rounded 1,600
    uint256 internal constant AMOUNT_P6 = 2_000 ether; // 100 hrs × $200 = $20,000 ÷ $8.52 ≈ 2,347 → rounded 2,000

    // =========================================================================
    // Proposal actions helpers
    // =========================================================================

    function _proposalActions(address acme, uint256 amount)
        internal
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](1);
        targets[0] = address(EXECUTOR);
        values = new uint256[](1);
        values[0] = 0;
        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(OlympiaExecutor.executeTreasury, (payable(acme), amount));
    }

    // =========================================================================
    // Proposal descriptions
    // =========================================================================

    function descP1(address acme) internal pure returns (string memory) {
        return string.concat(
            "[MOCK PROPOSAL] Wave 1, Proposal 1  --  Go 1.26 Runtime Modernization\n\n",
            "Developed by ACME Open Source Development Corp for Ethereum Classic DAO LLC\n",
            "Road to Olympia  --  Core-Geth Modernization March\n\n",
            "---\n",
            "About This Proposal\n\n",
            "Core-geth is Ethereum Classic's primary execution client. The current release ships on ",
            "Go 1.21, which reached end-of-life in August 2024 and no longer receives upstream ",
            "security patches from the Go team. This leaves ETC's node software running on an ",
            "unsupported toolchain with no path for upstream remediation.\n\n",
            "ACME Open Source Development Corp has developed and submitted this upgrade as an open ",
            "pull request to the core-geth repository (PR #10). This proposal requests funding for ",
            "that work through Olympia DAO's permissionless proposal process.\n\n",
            "Olympia enables any qualified open-source contributor to submit a funding proposal ",
            "directly to the ETC maintainer council for review and on-chain approval  --  providing a ",
            "transparent, auditable path for client maintenance work that benefits the entire network.\n",
            "---\n\n",
            "Summary\n\n",
            "Upgrades core-geth from Go 1.21 (EOL) to Go 1.26 (current stable), updates the blst ",
            "cryptographic library, and cascades all required x/ dependency updates for Go 1.26 ",
            "compatibility. This PR is the prerequisite foundation for ECFP-002 and ECFP-004.\n\n",
            "Scope (PR #10: https://github.com/ethereumclassic/core-geth/pull/10)\n\n",
            "- go.mod: Go 1.21 -> 1.26\n",
            "- 8 CI workflow files updated to Go 1.26\n",
            "- Dockerfiles: golang:1.21-alpine -> golang:1.26-alpine\n",
            "- fjl/memsize removed (incompatible with Go 1.23+ runtime.stopTheWorld linkname restriction)\n",
            "- blst v0.3.11 -> v0.3.16 (C23 harmonization, ARM64 BTI support, hardened 384-bit modular inversion)\n",
            "- x/ dependency cascade: tools, crypto, net, sys, sync, text, mod, time\n\n",
            "Cost Breakdown\n\n",
            "Role:       Senior Blockchain Engineer (Go, security, EVM)\n",
            "Rate:       $200 USD/hr (market rate, contract basis)\n",
            "Estimated:  60 hours of development, review, CI integration, and testing\n\n",
            "  60 hrs x $200/hr = $12,000 USD\n",
            "  $12,000 / $8.52 (ETC spot at proposal date) = 1,408 ETC (rounded to 1,200 ETC)\n\n",
            "This breakdown is published transparently so the ETC community can evaluate the true ",
            "market cost of maintaining its primary execution client. Equivalent work at established ",
            "organizations carries comparable costs embedded in operational budgets that are not visible ",
            "to the public. Olympia makes this accounting open and on-chain.\n\n",
            "Payment & Compliance\n\n",
            "Payer:     Ethereum Classic DAO LLC\n",
            "           The legal entity responsible for executing off-chain obligations on behalf of\n",
            "           Olympia DAO, including contractor payments and regulatory compliance reporting.\n\n",
            "Payee:     ACME Open Source Development Corp\n",
            "           An independent, OFAC-compliant registered company providing open-source software\n",
            "           development services to the Ethereum Classic network. ACME operates as an\n",
            "           external third party and holds no governance role within Olympia DAO.\n\n",
            "Amount:    1,200 ETC disbursed on-chain\n",
            "Reference: ECFP-001 | Recipient: ", _addrStr(acme), "\n",
            "Basis:     Software development services -- Core-Geth Modernization March, Wave 1\n",
            "           Statement of work: https://github.com/ethereumclassic/core-geth/pull/10\n\n",
            "This payment is structured as a business-to-business service agreement. ACME Open Source ",
            "Development Corp will recognize the USD equivalent as business revenue at the time of ",
            "on-chain disbursement. The ECFP submission and on-chain governance vote together ",
            "constitute the statement of work and payment authorization. Ethereum Classic DAO LLC ",
            "maintains all disbursement records on a public ledger for audit and regulatory compliance."
        );
    }

    function descP2(address acme) internal pure returns (string memory) {
        return string.concat(
            "[MOCK PROPOSAL] Wave 1, Proposal 2  --  Core Cryptography Hardening (4 CVEs)\n\n",
            "Developed by ACME Open Source Development Corp for Ethereum Classic DAO LLC\n",
            "Road to Olympia  --  Core-Geth Modernization March\n\n",
            "---\n",
            "About This Proposal\n\n",
            "Core-geth contains four confirmed cryptographic vulnerabilities rated CVSS 7.5 or higher. ",
            "These vulnerabilities affect the elliptic curve operations and ECIES encryption layer used ",
            "throughout the client. Patches have been developed and submitted as open pull requests. ",
            "This proposal funds the review, integration, and testing of all four fixes.\n\n",
            "Olympia DAO provides the coordination and funding layer for urgent security work that ",
            "benefits every node operator on the Ethereum Classic network.\n",
            "---\n\n",
            "Summary\n\n",
            "Four cryptographic vulnerabilities in core-geth's secp256k1 and ECIES implementations ",
            "are patched and submitted for review. All four are CVSS 7.5+ severity and affect the ",
            "client's cryptographic correctness guarantees.\n\n",
            "Scope\n\n",
            "PR #14 (CVE-2025-24883): UnmarshalPubkey accepts off-curve (x,y) points without curve ",
            "validation. An attacker can supply an invalid public key, causing undefined behavior ",
            "in downstream cryptographic operations.\n",
            "https://github.com/ethereumclassic/core-geth/pull/14\n\n",
            "PR #15 (CVE-2026-22862): ECIES Decrypt checks ciphertext minimum length using hLen+1 ",
            "instead of hLen+BlockSize, allowing truncated ciphertexts to pass validation and ",
            "potentially leaking plaintext bytes.\n",
            "https://github.com/ethereumclassic/core-geth/pull/15\n\n",
            "PR #16 (CVE-2026-26315): ECIES GenerateShared does not validate that the peer public key ",
            "is a valid curve point before performing ECDH derivation. A nil or off-curve key leads ",
            "to undefined behavior or key recovery attacks.\n",
            "https://github.com/ethereumclassic/core-geth/pull/16\n\n",
            "PR #17 (CVE-2026-26314): secp256k1 IsOnCurve does not reject coordinates >= field prime P. ",
            "The C-layer ignores secp256k1_fe_set_b32 return values, allowing crafted coordinates to ",
            "bypass curve validation and enabling signature forgery.\n",
            "https://github.com/ethereumclassic/core-geth/pull/17\n\n",
            "Cost Breakdown\n\n",
            "Role:       Senior Blockchain Engineer (Go, cryptography, EVM)\n",
            "Rate:       $200 USD/hr (market rate, contract basis)\n",
            "Estimated:  80 hours across 4 CVEs (security audit, patch, test, documentation per CVE)\n\n",
            "  80 hrs x $200/hr = $16,000 USD\n",
            "  $16,000 / $8.52 (ETC spot at proposal date) = 1,878 ETC (rounded to 1,600 ETC)\n\n",
            "Payment & Compliance\n\n",
            "Payer:     Ethereum Classic DAO LLC\n",
            "           The legal entity responsible for executing off-chain obligations on behalf of\n",
            "           Olympia DAO, including contractor payments and regulatory compliance reporting.\n\n",
            "Payee:     ACME Open Source Development Corp\n",
            "           An independent, OFAC-compliant registered company providing open-source software\n",
            "           development services to the Ethereum Classic network. ACME operates as an\n",
            "           external third party and holds no governance role within Olympia DAO.\n\n",
            "Amount:    1,600 ETC disbursed on-chain\n",
            "Reference: ECFP-002 | Recipient: ", _addrStr(acme), "\n",
            "Basis:     Software development services -- Core-Geth Modernization March, Wave 1\n",
            "           Statement of work:\n",
            "             https://github.com/ethereumclassic/core-geth/pull/14\n",
            "             https://github.com/ethereumclassic/core-geth/pull/15\n",
            "             https://github.com/ethereumclassic/core-geth/pull/16\n",
            "             https://github.com/ethereumclassic/core-geth/pull/17\n\n",
            "This payment is structured as a business-to-business service agreement. ACME will ",
            "recognize the USD equivalent as business revenue at the time of on-chain disbursement. ",
            "Ethereum Classic DAO LLC maintains all disbursement records on a public ledger for audit ",
            "and regulatory compliance."
        );
    }

    function descP3(address acme) internal pure returns (string memory) {
        return string.concat(
            "[MOCK PROPOSAL] Wave 1, Proposal 3  --  Dependency & Protocol Security (5 CVEs)\n\n",
            "Developed by ACME Open Source Development Corp for Ethereum Classic DAO LLC\n",
            "Road to Olympia  --  Core-Geth Modernization March\n\n",
            "---\n",
            "About This Proposal\n\n",
            "Core-geth carries five known vulnerabilities across its dependency tree and RPC layer. ",
            "These range from DoS vectors in the GraphQL and KZG subsystems to memory exhaustion ",
            "in cryptographic libraries. Patches are developed and submitted. This proposal funds ",
            "their integration and verification.\n",
            "---\n\n",
            "Summary\n\n",
            "Five dependency and protocol vulnerabilities are remediated across gjson, golang-jwt, ",
            "GraphQL, KZG blob proof handling, and gnark-crypto. The gnark-crypto fix depends on the ",
            "Go 1.26 upgrade from ECFP-001.\n\n",
            "Scope\n\n",
            "PR #12: gjson v1.6.0 -> v1.18.0. Four known vulnerabilities: stack exhaustion ",
            "(GO-2022-0957), unbounded recursion panic (GO-2021-0265), infinite loop DoS ",
            "(GO-2021-0059), panic in Get() (GO-2021-0054).\n",
            "https://github.com/ethereumclassic/core-geth/pull/12\n\n",
            "PR #13: golang-jwt/jwt v4.5.0 -> v4.5.2. Two vulnerabilities: token validation bypass ",
            "(GO-2025-3553) and memory exhaustion via crafted token claims (GO-2024-3250).\n",
            "https://github.com/ethereumclassic/core-geth/pull/13\n\n",
            "PR #18: GraphQL DoS via unbounded query nesting. Adds MaxDepth(20) limit (ported from ",
            "go-ethereum). Bumps graphql-go v1.3.0 -> v1.9.0 to fix MaxDepth enforcement.\n",
            "https://github.com/ethereumclassic/core-geth/pull/18\n\n",
            "PR #19 (CVE-2026-22868): KZG blob proof DoS. Peers sending transactions with invalid KZG ",
            "proofs trigger expensive cryptographic verification without consequence. Patch disconnects ",
            "offending peers on verification failure.\n",
            "https://github.com/ethereumclassic/core-geth/pull/19\n\n",
            "PR #20 (GO-2025-4087): gnark-crypto v0.12.1 -> v0.20.1. Unchecked memory allocation ",
            "during Vector deserialization allows remote OOM DoS. Includes go-kzg-4844 v0.7.0 -> ",
            "v1.1.0 for API compatibility. Depends on ECFP-001 (Go 1.26 required).\n",
            "https://github.com/ethereumclassic/core-geth/pull/20\n\n",
            "Cost Breakdown\n\n",
            "Role:       Senior Blockchain Engineer (Go, security, EVM)\n",
            "Rate:       $200 USD/hr (market rate, contract basis)\n",
            "Estimated:  70 hours across 5 CVEs and dependency updates\n\n",
            "  70 hrs x $200/hr = $14,000 USD\n",
            "  $14,000 / $8.52 (ETC spot at proposal date) = 1,643 ETC (rounded to 1,400 ETC)\n\n",
            "Payment & Compliance\n\n",
            "Payer:     Ethereum Classic DAO LLC\n",
            "           The legal entity responsible for executing off-chain obligations on behalf of\n",
            "           Olympia DAO, including contractor payments and regulatory compliance reporting.\n\n",
            "Payee:     ACME Open Source Development Corp\n",
            "           An independent, OFAC-compliant registered company providing open-source software\n",
            "           development services to the Ethereum Classic network. ACME operates as an\n",
            "           external third party and holds no governance role within Olympia DAO.\n\n",
            "Amount:    1,400 ETC disbursed on-chain\n",
            "Reference: ECFP-003 | Recipient: ", _addrStr(acme), "\n",
            "Basis:     Software development services -- Core-Geth Modernization March, Wave 1\n",
            "           Statement of work:\n",
            "             https://github.com/ethereumclassic/core-geth/pull/12\n",
            "             https://github.com/ethereumclassic/core-geth/pull/13\n",
            "             https://github.com/ethereumclassic/core-geth/pull/18\n",
            "             https://github.com/ethereumclassic/core-geth/pull/19\n",
            "             https://github.com/ethereumclassic/core-geth/pull/20\n\n",
            "This payment is structured as a business-to-business service agreement. ACME will ",
            "recognize the USD equivalent as business revenue at the time of on-chain disbursement. ",
            "Ethereum Classic DAO LLC maintains all disbursement records on a public ledger for audit ",
            "and regulatory compliance."
        );
    }

    function descP4(address acme) internal pure returns (string memory) {
        return string.concat(
            "[MOCK PROPOSAL] Wave 1, Proposal 4  --  P2P Protocol Security: CVE-2026-26313 & RLP Lazy Decoding\n\n",
            "Developed by ACME Open Source Development Corp for Ethereum Classic DAO LLC\n",
            "Road to Olympia  --  Core-Geth Modernization March\n\n",
            "---\n",
            "About This Proposal\n\n",
            "Core-geth's peer-to-peer message handling contains a memory DoS vulnerability ",
            "(CVE-2026-26313) that allows a malicious peer to trigger unbounded memory allocation ",
            "by sending crafted response messages. The upstream fix in go-ethereum required backporting ",
            "four foundational RLP lazy decoding primitives. This is the most structurally complex ",
            "item in Wave 1  --  it synthesizes four upstream pull requests into a single coherent ",
            "backport for the ETC codebase, requiring Go 1.26 generics from ECFP-001.\n",
            "---\n\n",
            "Summary\n\n",
            "Patches CVE-2026-26313 in core-geth's p2p message handling and backports the upstream ",
            "RLP lazy decoding infrastructure that underlies the structural fix.\n\n",
            "Scope\n\n",
            "PR #35 (CVE-2026-26313): A malicious peer can send a p2p response (BlockHeaders, ",
            "BlockBodies, Receipts, PooledTransactions, Transactions) with a valid RLP list header ",
            "claiming millions of tiny items. The 10 MiB maxMessageSize byte-size check passes, but ",
            "msg.Decode allocates pointer/struct objects proportional to item count via reflection ",
            "before validation  --  10 MiB of 1-byte RLP items (~10M items) causes OOM.\n",
            "https://github.com/ethereumclassic/core-geth/pull/35\n\n",
            "PR #36: Backports RLP lazy decoding primitives (rlp.RawList[T], iterator improvements) ",
            "from go-ethereum upstream PRs #33755, #33834, #33840, #33841. These enable delayed ",
            "decoding of p2p message contents  --  list content is stored as raw bytes and individual ",
            "elements decoded on demand, eliminating the allocation path CVE-2026-26313 exploits. ",
            "Requires Go 1.26 generics (ECFP-001 dependency).\n",
            "https://github.com/ethereumclassic/core-geth/pull/36\n\n",
            "Cost Breakdown\n\n",
            "Role:       Senior Blockchain Engineer (Go, p2p networking, EVM)\n",
            "Rate:       $200 USD/hr (market rate, contract basis)\n",
            "Estimated:  110 hours (CVE analysis, 4-PR upstream synthesis, backport, test coverage)\n\n",
            "  110 hrs x $200/hr = $22,000 USD\n",
            "  $22,000 / $8.52 (ETC spot at proposal date) = 2,582 ETC (rounded to 2,200 ETC)\n\n",
            "Payment & Compliance\n\n",
            "Payer:     Ethereum Classic DAO LLC\n",
            "           The legal entity responsible for executing off-chain obligations on behalf of\n",
            "           Olympia DAO, including contractor payments and regulatory compliance reporting.\n\n",
            "Payee:     ACME Open Source Development Corp\n",
            "           An independent, OFAC-compliant registered company providing open-source software\n",
            "           development services to the Ethereum Classic network. ACME operates as an\n",
            "           external third party and holds no governance role within Olympia DAO.\n\n",
            "Amount:    2,200 ETC disbursed on-chain\n",
            "Reference: ECFP-004 | Recipient: ", _addrStr(acme), "\n",
            "Basis:     Software development services -- Core-Geth Modernization March, Wave 1\n",
            "           Statement of work:\n",
            "             https://github.com/ethereumclassic/core-geth/pull/35\n",
            "             https://github.com/ethereumclassic/core-geth/pull/36\n\n",
            "This payment is structured as a business-to-business service agreement. ACME will ",
            "recognize the USD equivalent as business revenue at the time of on-chain disbursement. ",
            "Ethereum Classic DAO LLC maintains all disbursement records on a public ledger for audit ",
            "and regulatory compliance."
        );
    }

    function descP5(address acme) internal pure returns (string memory) {
        return string.concat(
            "[MOCK PROPOSAL] Wave 2, Proposal 5  --  ETC Chain Config & Consensus Unit Tests\n\n",
            "Developed by ACME Open Source Development Corp for Ethereum Classic DAO LLC\n",
            "Road to Olympia  --  Core-Geth Modernization March\n\n",
            "---\n",
            "About This Proposal\n\n",
            "Ethereum Classic has accumulated over a decade of chain-specific protocol rules: the ",
            "ECIP-1017 emission schedule, ECBP-1100 anti-selfish-mining rule, ETChash difficulty ",
            "adjustments, and 14 named fork boundaries. None of these are covered by upstream ",
            "go-ethereum tests. Core-geth ships with ETC-specific behavior that has no dedicated ",
            "test coverage  --  meaning regressions in fork logic, emission calculation, or gas rules ",
            "could go undetected.\n\n",
            "This proposal funds the first comprehensive unit test suite for ETC's consensus rules, ",
            "giving the community confidence in the client's correctness and enabling safe future ",
            "modifications.\n",
            "---\n\n",
            "Summary\n\n",
            "Six pull requests add 41 unit and integration tests covering ETC chain configuration ",
            "validation, gas limit rules, fork compliance, ECIP-1017 emission schedule, ETChash ",
            "difficulty, and dead code removal.\n\n",
            "Scope\n\n",
            "PR #21: Remove dead TerminalTotalDifficulty field (ETC is PoW  --  TTD is Ethereum-specific). ",
            "Add geth binary to .gitignore.\n",
            "https://github.com/ethereumclassic/core-geth/pull/21\n\n",
            "PR #23: 13 unit tests  --  chain config validation for Classic mainnet and Mordor testnet: ",
            "fork block ordering, chain ID (61/63), ECBP-1100 activation/deactivation, network ID.\n",
            "https://github.com/ethereumclassic/core-geth/pull/23\n\n",
            "PR #24: 8 unit tests  --  gas limit adjustment rules: 1/1024 per-block adjustment bound, ",
            "8M gas target, boundary conditions, minimum floor (5000).\n",
            "https://github.com/ethereumclassic/core-geth/pull/24\n\n",
            "PR #25: 10 integration tests  --  ETC fork compliance and EVM opcode activation per fork ",
            "(REVERT, SHL/SHR/SAR, CREATE2, CHAINID, SELFBALANCE, PUSH0) across all named forks.\n",
            "https://github.com/ethereumclassic/core-geth/pull/25\n\n",
            "PR #26: 4 integration tests  --  ECIP-1017 emission reduction schedule: Era 1-4 block ",
            "rewards and uncle reward calculations per era.\n",
            "https://github.com/ethereumclassic/core-geth/pull/26\n\n",
            "PR #27: 6 tests  --  ETChash difficulty calculations: ECIP-1010 delay, ECIP-1041 disposal, ",
            "ECIP-1099 epoch length doubling, minimum difficulty floor (131072).\n",
            "https://github.com/ethereumclassic/core-geth/pull/27\n\n",
            "Cost Breakdown\n\n",
            "Role:       Senior Blockchain Engineer (Go, EVM, consensus)\n",
            "Rate:       $200 USD/hr (market rate, contract basis)\n",
            "Estimated:  80 hours across 6 PRs (test design, implementation, CI integration)\n\n",
            "  80 hrs x $200/hr = $16,000 USD\n",
            "  $16,000 / $8.52 (ETC spot at proposal date) = 1,878 ETC (rounded to 1,600 ETC)\n\n",
            "Payment & Compliance\n\n",
            "Payer:     Ethereum Classic DAO LLC\n",
            "           The legal entity responsible for executing off-chain obligations on behalf of\n",
            "           Olympia DAO, including contractor payments and regulatory compliance reporting.\n\n",
            "Payee:     ACME Open Source Development Corp\n",
            "           An independent, OFAC-compliant registered company providing open-source software\n",
            "           development services to the Ethereum Classic network. ACME operates as an\n",
            "           external third party and holds no governance role within Olympia DAO.\n\n",
            "Amount:    1,600 ETC disbursed on-chain\n",
            "Reference: ECFP-005 | Recipient: ", _addrStr(acme), "\n",
            "Basis:     Software development services -- Core-Geth Modernization March, Wave 2\n",
            "           Statement of work:\n",
            "             https://github.com/ethereumclassic/core-geth/pull/21\n",
            "             https://github.com/ethereumclassic/core-geth/pull/23\n",
            "             https://github.com/ethereumclassic/core-geth/pull/24\n",
            "             https://github.com/ethereumclassic/core-geth/pull/25\n",
            "             https://github.com/ethereumclassic/core-geth/pull/26\n",
            "             https://github.com/ethereumclassic/core-geth/pull/27\n\n",
            "This payment is structured as a business-to-business service agreement. ACME will ",
            "recognize the USD equivalent as business revenue at the time of on-chain disbursement. ",
            "Ethereum Classic DAO LLC maintains all disbursement records on a public ledger for audit ",
            "and regulatory compliance."
        );
    }

    function descP6(address acme) internal pure returns (string memory) {
        return string.concat(
            "[MOCK PROPOSAL] Wave 2, Proposal 6  --  Live RPC Tests, Cross-Client Vectors & Repository Hygiene\n\n",
            "Developed by ACME Open Source Development Corp for Ethereum Classic DAO LLC\n",
            "Road to Olympia  --  Core-Geth Modernization March\n\n",
            "---\n",
            "About This Proposal\n\n",
            "Multi-client ETC compatibility requires shared test infrastructure that does not currently ",
            "exist. There are no shared JSON consensus test vectors for ETC's fork parameters, no live ",
            "RPC integration tests that verify ECBP-1100 or ECIP-1099 behavior against a real node, ",
            "and no precompile regression tests across fork boundaries. Without this infrastructure, ",
            "each new client implementation must independently rediscover ETC's chain-specific rules.\n\n",
            "Additionally, the core-geth README continues to reference deprecated networks, projects, ",
            "and CI systems from the go-ethereum era, creating confusion for new contributors and ",
            "node operators approaching the repository.\n\n",
            "This proposal funds the multi-client test infrastructure and repository modernization ",
            "that will serve Ethereum Classic development for years to come.\n",
            "---\n\n",
            "Summary\n\n",
            "Five pull requests add 30+ live RPC and precompile tests, shared JSON consensus vectors, ",
            "and a full README rewrite for the ETC context.\n\n",
            "Scope\n\n",
            "PR #28: 13 live RPC integration tests for Mordor and ETC mainnet: genesis block validation, ",
            "chain ID, network version, all 14 ECIP-1066 forks, ECIP-1017 era reward verification.\n",
            "https://github.com/ethereumclassic/core-geth/pull/28\n\n",
            "PR #29: 9 live RPC tests  --  ECBP-1100 (MESS) verification, ECIP-1099 epoch length doubling, ",
            "Spiral EIP-3855/3860/6049 verification. Depends on PR #28.\n",
            "https://github.com/ethereumclassic/core-geth/pull/29\n\n",
            "PR #30: 4 precompile regression tests across fork boundaries  --  activation/deactivation, ",
            "gas cost repricing (ecRecover, sha256, ripemd160, identity, modexp, bn256), ",
            "Blake2F at Magneto, precompile registry consistency.\n",
            "https://github.com/ethereumclassic/core-geth/pull/30\n\n",
            "PR #31: Shared JSON consensus test vectors for cross-client ETC validation  --  fork block ",
            "numbers for Classic mainnet and Mordor, known block hashes at fork boundaries, ECIP-1017 ",
            "emission schedule vectors, difficulty calculation vectors, ECBP-1100 activation blocks.\n",
            "https://github.com/ethereumclassic/core-geth/pull/31\n\n",
            "PR #34: Full README rewrite for the ETC context. Removes references to etclabscore, ",
            "Ellaism, Morden, Ropsten, Rinkeby, Kovan, MintMe, Travis CI, and Gitter. Adds accurate ",
            "ETC chain parameters, ECIP index, multi-client context, and current network information.\n",
            "https://github.com/ethereumclassic/core-geth/pull/34\n\n",
            "Cost Breakdown\n\n",
            "Role:       Senior Blockchain Engineer (Go, EVM, multi-client)\n",
            "Rate:       $200 USD/hr (market rate, contract basis)\n",
            "Estimated:  100 hours across 5 PRs (test design, live node integration, documentation)\n\n",
            "  100 hrs x $200/hr = $20,000 USD\n",
            "  $20,000 / $8.52 (ETC spot at proposal date) = 2,347 ETC (rounded to 2,000 ETC)\n\n",
            "Payment & Compliance\n\n",
            "Payer:     Ethereum Classic DAO LLC\n",
            "           The legal entity responsible for executing off-chain obligations on behalf of\n",
            "           Olympia DAO, including contractor payments and regulatory compliance reporting.\n\n",
            "Payee:     ACME Open Source Development Corp\n",
            "           An independent, OFAC-compliant registered company providing open-source software\n",
            "           development services to the Ethereum Classic network. ACME operates as an\n",
            "           external third party and holds no governance role within Olympia DAO.\n\n",
            "Amount:    2,000 ETC disbursed on-chain\n",
            "Reference: ECFP-006 | Recipient: ", _addrStr(acme), "\n",
            "Basis:     Software development services -- Core-Geth Modernization March, Wave 2\n",
            "           Statement of work:\n",
            "             https://github.com/ethereumclassic/core-geth/pull/28\n",
            "             https://github.com/ethereumclassic/core-geth/pull/29\n",
            "             https://github.com/ethereumclassic/core-geth/pull/30\n",
            "             https://github.com/ethereumclassic/core-geth/pull/31\n",
            "             https://github.com/ethereumclassic/core-geth/pull/34\n\n",
            "This payment is structured as a business-to-business service agreement. ACME will ",
            "recognize the USD equivalent as business revenue at the time of on-chain disbursement. ",
            "Ethereum Classic DAO LLC maintains all disbursement records on a public ledger for audit ",
            "and regulatory compliance."
        );
    }

    // =========================================================================
    // Internal utility
    // =========================================================================

    /// @dev Converts an address to its checksummed hex string representation for embedding in proposal text.
    function _addrStr(address a) internal pure returns (string memory) {
        bytes memory b = new bytes(42);
        b[0] = "0";
        b[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            uint8 hi = uint8(uint160(a) >> (4 * (39 - 2 * i))) & 0xf;
            uint8 lo = uint8(uint160(a) >> (4 * (38 - 2 * i))) & 0xf;
            b[2 + 2 * i] = _hexChar(hi);
            b[3 + 2 * i] = _hexChar(lo);
        }
        return string(b);
    }

    function _hexChar(uint8 v) private pure returns (bytes1) {
        return v < 10 ? bytes1(v + 48) : bytes1(v + 87);
    }
}
