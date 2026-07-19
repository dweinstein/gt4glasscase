"
One safetensors shard. Lazy header parse: 8-byte little-endian length + JSON header (tensor name -> dtype/shape/offsets), then the raw buffer. Holds refs, never the bytes (I5).
"
Class {
	#name : 'GcSafetensorsFile',
	#superclass : 'Object',
	#instVars : [
		'path',
		'header',
		'tensors',
		'byteDataOffset'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}
