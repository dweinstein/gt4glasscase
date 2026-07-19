"
A known-poisoned control processed by the full pipeline. The pipeline MUST flag it; its sensitivity curve turns a null result into a bounded negative result.
"
Class {
	#name : 'GcCalibrationRun',
	#superclass : 'Object',
	#instVars : [
		'poisonStrength',
		'detected'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}
