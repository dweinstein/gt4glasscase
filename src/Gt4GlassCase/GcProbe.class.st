"
A question with a checkable property. Must declare its null hypothesis and variation axis at construction -- a design constraint against post-hoc fishing. minimumSeeds is fixed up front.
"
Class {
	#name : 'GcProbe',
	#superclass : 'Object',
	#instVars : [
		'template',
		'variationAxis',
		'fixedBindings',
		'oracle',
		'nullHypothesis',
		'expectedDirection',
		'minimumSeeds',
		'family'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}
