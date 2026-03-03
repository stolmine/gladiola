gladiola

a groovebox built from basic principles, designed for grid

interaction / goals / output

output - complex simple - overlay/in-between/density/offset/masking/interference patterns/ - tonal, clicks and cuts, idm, kangding ray's stabil is a reference

interaction - deterministic, yet networked behavior - decisions should compile and complicate each other. what would this actually look like? good question

positional data is most of what we have, but we also have 16 levels of brightness which provides a third dimension to play with

traditional models:
- chaselight - a playhead passes over and plays high positions, low positions are ignored. we can stack these efficiently into an interface if we like. this is essentially what any sequencer boils down to, the interest comes in terms of modifying how high/low status is chosen
- algorithmic - we modify parameters to generate sequence data, high positions are chosen or distributed mathmematically

on top of these two we can expand the dimension of each high step to include more information: pitch, velocity, sample selection, synth parameters, etc. we can pack as much of this in as we like, really

we can also alter the behavior of the playhead, often we see this in a direction or clock div parameter

here's a curious idea: something like tape. we have a read head (which handles playback) and a write head (our finger which chooses steps), the write head is constantly being fed the audio coming off the playhead, the user can place steps which consist of a piece of audio (the last thing captured by the read head)
- parameters
	- capture length
	- playback length
	- what is the initial source?
	- clock speed
	- read/write delay (change capture offset of read head, only backward i suppose)
another idea, perhaps more of a straight up UI than anything else: a chaselight seq, typical push to add step notion. but when one holds down a step, you can select options from the correpsonding column and row of buttons. this would give us 7 options vertically, and 15 horizontally. what these would represent is the question. 

ease of use would demand just two parameters. i kind of enjoy the idea of chance here, the parameters are randomized per step at script load. this would require some pretty high level abstraction or macro action

or perhaps, one dimension could represent a parameter, and the other could vary that parameter or choose from versions of an effect or whatnot. this feels fun and doable

my instinct is to go sample based. this would be fun for loops or breaks. would require time stretching infrastructure

let's start here:
	- simple chaselight, the seq is as long as 128 steps, covering the whole grid
	- single voice
	- user can double tap top left button, to make the rest of the grid flash (representing length selection modal). they tap another button to set endpoint for the pattern
	- playhead moves left to right, top to bottom
	- we tap a given step to activate, tap again to deac
	- hold to enter parameter menu
	- per step we get seven parameters, these will dynamically allocate to those buttons in the column the user is not holding.
		- 0. sample bank selection / tap column slot 0 to cycle through banks (brightness indicates current bank, up to 16 banks). untouched buttons on current row represent 15 samples within the selected bank. 16 banks × 15 samples = 240 samples total
	- sample loading: recursive scan of a root sample directory
		- by subdirectory (default): each subfolder becomes a bank. >15 samples spills into next bank
		- random: shuffle entire collection, fill banks sequentially
		- sequential: filesystem order, 15 per bank
		- 1. pitch
		- 2. velocity
		- 3. loop length (in subdivisions or percentage of total length), lowest value is off
		- 4. loop region (dynamically allocated within the length of a loaded sample)
		- 5. ratchet
		- 6. randomness - chaotically mutates all other parameters per read from the playhead to nth degree, or within X range expressed as percentage range mapped to parameter space of each parameter
