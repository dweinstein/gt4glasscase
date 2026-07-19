"
Modal REST/CLI client: workspace + token. Pins the image digest into each job spec.
"
Class {
	#name : 'GcModalBackend',
	#superclass : 'GcComputeBackend',
	#instVars : [
		'workspace',
		'token',
		'appId',
		'baseUrl'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}
