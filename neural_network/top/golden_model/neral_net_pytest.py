#!/usr/bin/python

import sys
import random
import math

import pickle
import json

import gzip

import PIL
from PIL import Image
import numpy as np

RATIO = 0.1
BATCH_SIZE = 1

def sigmoid(x):
	# if x > 0 :
	# 	return x
	# else :
	# 	return 0
	try:
		s = 1.0 / (1.0 + math.exp(-x))
	except:
		print ("ERROR sig - " + str(x))
		s = 0.999999999
	
	return s

def dsigmoid(y):
	# if y > 0:
	# 	return 1
	# else :
		# return 0
	return y * (1.0 - y)

class neuron_t(object):
	
	def __init__(self, num_of_w):
		self.weights_arr = []
		self.a_l = 0
		self.bias = np.random.randn()
		self.weights_arr = np.random.randn(num_of_w)

		self.grad_cnt    = 0
		self.grad_bias   = 0
		self.grad_weight = []
		self.grad_weight = np.zeros(num_of_w)

	def print(self):
		print ("		bias = " + str(self.bias))
		print ("		weights =")
		print (self.weights_arr)
		print ("")

	def feedfoward(self, a_lm1_arr):

		if len(a_lm1_arr) != len(self.weights_arr):
			print ("neuron got wrong size of a_lm1_arr")
			exit()

		self.a_l = self.bias
		for weight_i in range(0, len(self.weights_arr)):
			self.a_l += a_lm1_arr[weight_i] * self.weights_arr[weight_i];
		self.a_l = sigmoid(self.a_l)
		return (self.a_l)

	def backpropagation(self, a_lm1_arr, error):
		if len(a_lm1_arr) != len(self.weights_arr):
			print ("neuron got wrong size of a_lm1_arr")
			exit()

		factor = RATIO * error / BATCH_SIZE;
		self.grad_bias += factor
		for weight_i in range(0, len(self.weights_arr)):
			self.grad_weight[weight_i] += (factor * a_lm1_arr[weight_i]);

		self.grad_cnt += 1

		if self.grad_cnt == BATCH_SIZE :
			self.bias -= self.grad_bias
			self.weights_arr[weight_i] -= self.grad_weight[weight_i];

			self.grad_cnt = 0
			self.grad_bias = 0.0
			for weight_i in range(0, len(self.weights_arr)):
				self.grad_weight[weight_i] = 0.0


class layer_t(object):

	def __init__(self, num_of_neurons, weigths_size):
		self.neurons_arr  = []
		self.weigths_size = weigths_size

		# For every neuron.
		for neuron_i in range(0, num_of_neurons):
			self.neurons_arr.append(neuron_t(weigths_size));

	def print(self):
		for neuron_i in range(0, len(self.neurons_arr)):
			print ("	neuron " + str(neuron_i) + " = ")
			print (self.neurons_arr[neuron_i].print())

	def feedfoward(self, a_lm1_arr):
		a_l_arr = []

		for neuron_i in range(0, len(self.neurons_arr)):
			a_l_arr.append(self.neurons_arr[neuron_i].feedfoward(a_lm1_arr))

		return (a_l_arr)		

	def backpropagation(self, a_lm1_arr, error_arr):
		if len(a_lm1_arr) != self.weigths_size:
			print ("layer got wrong size a_lm1_arr")
			exit()

		if len(error_arr) != len(self.neurons_arr):
			print ("layer got wrong size of error_arr")
			exit()

		for neuron_i in range(0, len(self.neurons_arr)):
			self.neurons_arr[neuron_i].backpropagation(a_lm1_arr, error_arr[neuron_i])

class network_t(object):

	"""docstring for network"""
	def __init__(self, network_sizes):  # TODO - xrange
		self.layers_arr       = []
		self.input_layer_size = network_sizes[0] 

		# Walk through the layers
		for layer_i in range(1, len(network_sizes)):
			self.layers_arr.append(layer_t(network_sizes[layer_i], network_sizes[layer_i - 1]))

		self.MAX_E = 0.0
		self.MIN_E = 0.0


	def print(self):
		for layer_i in range(0,len(self.layers_arr)):
			print ("layer " + str(layer_i) + " : ")
			print ("-------------------------")
			print (self.layers_arr[layer_i].print())

	def feedfoward(self, input_layer_arr):
		if len(input_layer_arr) != self.input_layer_size:
			print ("network got wrong size input_layer_arr")
			exit()

		for layer_i in range(0, len(self.layers_arr)):
			output_layer_arr = self.layers_arr[layer_i].feedfoward(input_layer_arr);
			input_layer_arr = output_layer_arr

		return (output_layer_arr)


	def learn(self, input_layer_arr, output_targets_arr):
		a_l_arr 		= []
		errors_arr 		= []
		curr_errors_arr = []
		prev_errors_arr = []


		if len(input_layer_arr) != self.input_layer_size:
			print ("network got wrong size of input_layer_arr")
			exit()

		if len(output_targets_arr) != len(self.layers_arr[len(self.layers_arr)-1].neurons_arr):
			print ("network got wrong size of output_targets_arr")
			exit()

		# Save the input layer.
		a_l_arr.append(input_layer_arr);

		# Feedfoward the network and save outputs.
		for layer_i in range(0, len(self.layers_arr)):
			a_l_arr.append(self.layers_arr[layer_i].feedfoward(a_l_arr[layer_i]));

		# Calc output layer error then and back propagation for the error.
		for neuron_i in range(0, len(output_targets_arr)):
			e = a_l_arr[len(a_l_arr)-1][neuron_i] - output_targets_arr[neuron_i];
			curr_errors_arr.append(e * dsigmoid(a_l_arr[len(a_l_arr)-1][neuron_i]));
			
		# Staring from the last layer to the first
		for layer_i in reversed(range(0, len(self.layers_arr))):

			# Clear prev errors
			prev_errors_arr = []

			# Check if there is error to calc 
			if layer_i != 0 :
	
				# For all the neurons in the prev layer calc error by the current layer weights
				for neuron_i in range(0, len(self.layers_arr[layer_i-1].neurons_arr)):

					prev_error = 0.0

					# It doesn't matter neuron_i because all the neurons have the same weigth size 
					for neuron_j in range(0, len(self.layers_arr[layer_i].neurons_arr)):
						w = self.layers_arr[layer_i].neurons_arr[neuron_j].weights_arr[neuron_i];
						prev_error += w * curr_errors_arr[neuron_j];

						if (self.MIN_E > prev_error):
							self.MIN_E = prev_error
						if (self.MAX_E < prev_error):
							self.MAX_E = prev_error
						
					# if (prev_error > 1.0):
					# 	prev_error = 1.0
					# if (prev_error < -1.0):
					# 	prev_error = -1.0

					prev_error = prev_error * dsigmoid(a_l_arr[layer_i][neuron_i]);
					prev_errors_arr.append(prev_error);

			errors_arr.insert(0, curr_errors_arr)
			curr_errors_arr = prev_errors_arr

		# Now, when we have our errors and the previous one we can backpropagation.
		for layer_i in reversed(range(0, len(self.layers_arr))):
			self.layers_arr[layer_i].backpropagation(a_l_arr[layer_i], errors_arr[layer_i]);

def xor_test():
	net = network_t([2,2,1])
	# net = network_t([2,2,2,2,2,1])

	i = [[0.0,0.0],[0.0,1.0],[1.0,0.0],[1.0,1.0]] 
	o = [[0.0],[1.0],[1.0],[0.0]]

	net.print()

	print ("--- Before ---")
	print ("expected:")
	print (o[0])
	print ("recieved:")
	print (net.feedfoward(i[0]))

	print ("expected:")
	print (o[1])
	print ("recieved:")
	print (net.feedfoward(i[1]))

	print ("expected:")
	print (o[2])
	print ("recieved:")
	print (net.feedfoward(i[2]))

	print ("expected:")
	print (o[3])
	print ("recieved:")
	print (net.feedfoward(i[3]))


	print ("--- Training ---")
	print ("      ...")

	for x in range(1,100000):
		a = random.randrange(4)
		net.learn(i[a], o[a])

	print ("--- Checking ---")
	print ("expected:")
	print (o[0])
	print ("recieved:")
	print (net.feedfoward(i[0]))

	print ("expected:")
	print (o[1])
	print ("recieved:")
	print (net.feedfoward(i[1]))

	print ("expected:")
	print (o[2])
	print ("recieved:")
	print (net.feedfoward(i[2]))

	print ("expected:")
	print (o[3])
	print ("recieved:")
	print (net.feedfoward(i[3]))

	print ("--- Done ---")
	print ("Min = " + str(net.MIN_E))
	print ("Max = " + str(net.MAX_E))
	
	print ("--- Result ---")
	# net.print()
	del(net)

def image_test():
	
	net = network_t([784, 784, 30, 30, 30, 10])

	f = open("C:\\Users\\shay\\Desktop\\Rotem\\neural-networks-and-deep-learning-master\\fig\\data_1000.json")
	data_1000 = json.load(f)

	print ("--- Training ---")
	print ("      ...")


	for x in range(1,100):
		# Run over the training data.
		for i in range(0,len(data_1000["training"])):
			net.learn(data_1000["training"][i]["x"], data_1000["training"][i]["y"])

		# Shuffle training data.
		random.shuffle(data_1000["training"])

	print ("--- Checking ---")
	# for x in range(0,len(data_1000["validation"])):
	for x in range(0,10):
		res = net.feedfoward(data_1000["training"][x]["x"])
		
		# if (data_1000["training"][x]["y"][2] == 1.0):
		# 	print ("--- AAA ---")
		# 	print (res)
		# elif (res[0] > 0.7):
		# 	print ("--- BBB ---")
		# 	print (data_1000["training"][x]["y"])
		if (res.index(max(res)) != data_1000["training"][x]["y"]):
			print ("--- ERROR ---")
			print ("expected:")
			print (data_1000["training"][x]["y"])
			print ("recieved:")
			print (res.index(max(res)))
			print (res)
			print ("")
		else : 
			print ("--- SUCCESS ---")
			print (res[data_1000["training"][x]["y"]])

	print ("--- Done ---")
	print ("Min = " + str(net.MIN_E))
	print ("Max = " + str(net.MAX_E))
	
	print ("--- Result ---")
	# net.print()
	del(net)

def pil_test():

	im = Image.open("C:\\Users\\shay\\Desktop\\image1.png")
	px = im.load()
	
	print (px[4,4])
	px[4,4] = (0,0,50,255)
	print (px[4,4])
	
	pix = np.array(im)
	print (pix.size)
	print (im.size)
	print (pix.shape)
	print (pix.dtype)
	print (type(pix[0,0,0]))
	Image.fromarray(pix).save("C:\\Users\\shay\\Desktop\\image1.png")

def check_training():
	
	f = open("C:\\Users\\shay\\Desktop\\Rotem\\neural-networks-and-deep-learning-master\\fig\\data_1000.json")
	data_1000 = json.load(f)

	pix = np.zeros((28,28,4), dtype=np.uint8)

	for i in range(0,28):
		for j in range(0,28):
			for t in range(0,4):
				if t == 0:
					pix[i][j][t] = np.uint8(255*data_1000["validation"][1]["x"][i*28+j])
				else :
					pix[i][j][t] = 255

	Image.fromarray(pix).save("C:\\Users\\shay\\Desktop\\image2.png")

def main():
	xor_test()

if __name__ == '__main__':
	main()