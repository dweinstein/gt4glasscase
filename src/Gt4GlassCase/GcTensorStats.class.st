"
Cached numeric summary of a tensor: moments, norms, sparsity, spectrum. Tier-1 computed in-image from sampled slices; Tier-2 (SVD, spectra) delegated to Python and cached here.
"
Class {
	#name : 'GcTensorStats',
	#superclass : 'Object',
	#instVars : [
		'tensorRef',
		'min',
		'max',
		'mean',
		'std',
		'sparsity',
		'spectralEntropy'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}
