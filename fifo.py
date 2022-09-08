class fifo:
	def __init__(self, depth=8):
		self.inner = [0 for _ in range(depth)]
		self.depth = depth

	def push(self, val):
		# roll fwd
		self.inner[1:] = self.inner[0:self.depth-1]
		self.inner[0] = val
		print(f'{self.inner = }')

	def peek(self):
		return self.inner[-1]

f = fifo()
for i in range(16):
	print(f'{i}<-{i}')
	f.push(i)
	print(f'{i}->{f.peek()}')