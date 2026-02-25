#!/usr/bin/env python3

# Extract key parameters from TX3 setUp call more carefully
# The setUp call has signature: setUp(bytes) where bytes encodes the struct

# TX3 setUp call data (without 0xa4f9edbf selector):
setup_data = "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000016000000000000000000000000036bd3044ab68f600f6d3e081056f34f2a58432c4000000000000000000000000e485e2f1bab389C08721B291f6b59780feC83Fd7000000000000000000000000aa6bfa174d2f803b517026e93dbbec1eba26258e00000000000000000000000000000000000000000000000000000000000054600000000000000000000000000000000000000000000000000000000000007530000000000000000000000000000000000000000000000000000000000007a1200000000000000000000000003bc1a0ad72417f2d411118085256fc53cbddd13700000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000400cdfef5e2714e63d8040b700bc24000000000000000000000000000000000000000000000000000000000000000100000040000100020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

# Skip the first 0x20 (points to data start) and 0x160 (data length)
# Real struct data starts at position 128 hex chars in

print("TX3 setUp struct parameters:")
print("owner: 0x" + setup_data[88:128])
print("governanceToken: 0x" + setup_data[152:192]) 
print("azoriusModule: 0x" + setup_data[216:256])

# These should be 32-byte values interpreted as smaller integers
voting_period = int(setup_data[256:320], 16)
quorum_numerator = int(setup_data[320:384], 16)
basis_numerator = int(setup_data[384:448], 16)

print("votingPeriod:", voting_period)
print("quorumNumerator:", quorum_numerator)
print("basisNumerator:", basis_numerator)
print("hatsContract: 0x" + setup_data[472:512])

# The hatId and proposerThreshold 
hat_id = "0x" + setup_data[576:640]
proposer_threshold = "0x" + setup_data[640:704]

print("hatId:", hat_id)
print("proposerThreshold:", proposer_threshold)

# Convert the large hex to decimal for proposerThreshold
proposer_threshold_decimal = int(proposer_threshold, 16)
print("proposerThreshold decimal:", proposer_threshold_decimal)

print("\nExpected values based on task description:")
print("votingPeriod should be: 21600 (0x5460)")
print("quorumNumerator should be: 30000 (0x7530) - 30% in basis points") 
print("basisNumerator should be: 500000 (0x7a120) - 50% threshold")

print("\nActual values:")
print("votingPeriod:", hex(voting_period))
print("quorumNumerator:", hex(quorum_numerator))
print("basisNumerator:", hex(basis_numerator))