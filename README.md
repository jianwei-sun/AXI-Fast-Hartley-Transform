# AXI-Fast-Hartley-Transform
An FHT core for audio pitch detection

## Usage
The FHT loads in default memory values (constants for the FHT algorithm) using the readmemh command. Replace the directory in the IP core with your local directory, and repackage.

## Design
The input to the FHT core is an internal FIFO. Currently, that FIFO is fed with data acquired from the on-board PDM microphone. If you would like to use just the FHT component of the core, modifiy the core by removing the microphone interface. 

## Registers
+0: Busy Register
	This read only register contains the value 1 when an FHT conversion is currently in operation, and a 0 when the core is idle.
+4: Frequency Register
	The dominant frequency result is stored in this register. The result is in Hertz.
+8: Amplitude Register
	The corresponding amplitude of the dominant frequency is stored in this register. Note that this amplitude does not have SI units due to optimizations made in the core. 
+12: Start Register
	This is the only writable register. Write a 1 to this register to start a new FHT calculation. This register can only be written when the Busy Register is not 1. This start register is automatically cleared one clock cycle after it is written. 

