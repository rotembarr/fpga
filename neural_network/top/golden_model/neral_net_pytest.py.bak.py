#!/usr/bin/python

import sys
import random
import math

import pickle
import json

import gzip

RATIO = 0.1

def sigmoid(x):
	return 1 / (1 + math.exp(-x))

def dsigmoid(y):
	return y * (1 - y)

class neuron_t(object):
	
	def __init__(self, num_of_w):
		self.weights_arr = []
		self.a_l = 0
		self.bias = random.uniform(-1, 1)
		for weight_i in range(0, num_of_w):
			self.weights_arr.append(random.uniform(-1, 1))

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

		factor = RATIO * error * dsigmoid(self.a_l);
		self.bias += factor
		for weight_i in range(0, len(self.weights_arr)):
			self.weights_arr[weight_i] += (factor * a_lm1_arr[weight_i]);

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
			curr_errors_arr.append(output_targets_arr[neuron_i] - a_l_arr[len(a_l_arr) - 1][neuron_i]);
			
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
						# b = sum(self.layers_arr[layer_i].neurons_arr[neuron_j].weights_arr)
						a = self.layers_arr[layer_i].neurons_arr[neuron_j].weights_arr[neuron_i]
						prev_error += (a) * curr_errors_arr[neuron_j];

						if (self.MIN_E > prev_error):
							self.MIN_E = prev_error
						if (self.MAX_E < prev_error):
							self.MAX_E = prev_error
						
					# if (prev_error > 1.0):
					# 	prev_error = 1.0
					# if (prev_error < -1.0):
					# 	prev_error = -1.0

					prev_errors_arr.append(prev_error);

			errors_arr.insert(0, curr_errors_arr)
			curr_errors_arr = prev_errors_arr

		# Now, when we have our errors and the previous one we can backpropagation.
		for layer_i in reversed(range(0, len(self.layers_arr))):
			self.layers_arr[layer_i].backpropagation(a_l_arr[layer_i], errors_arr[layer_i]);

def main():
	
	net = network_t([784,16,10,10,10])

	f = open("C:\\Users\\shay\\Desktop\\Rotem\\neural-networks-and-deep-learning-master\\fig\\data_1000.json")
	data_1000 = json.load(f)

	print ("--- Training ---")
	print ("      ...")

	# for x in range(1,10):
	for i in range(0,len(data_1000["training"])):
		net.learn(data_1000["training"][i]["x"], data_1000["training"][i]["y"])



	print ("--- Checking ---")
	print ("expected:")
	print (data_1000["validation"][10]["y"])
	print ("recieved:")
	print (net.feedfoward(data_1000["validation"][10]["x"]))

	print ("--- Done ---")
	print ("Min = " + str(net.MIN_E))
	print ("Max = " + str(net.MAX_E))
	
	print ("--- Result ---")
	# net.print()
	del(net)

if __name__ == '__main__':
	main()