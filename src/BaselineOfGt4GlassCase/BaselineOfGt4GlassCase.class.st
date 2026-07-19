Class {
	#name : 'BaselineOfGt4GlassCase',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfGt4GlassCase',
	#package : 'BaselineOfGt4GlassCase'
}

{ #category : 'loading' }
BaselineOfGt4GlassCase class >> loadLepiter [
	IceRepository registry  
		detect: [ :aRepository |
			aRepository name = 'gt4glasscase' ]
		ifFound: [ :aRepository | 
			| defaultDatabase currentProperties |
			defaultDatabase := LeDatabasesRegistry defaultLogicalDatabase.
			currentProperties := defaultDatabase properties.
			currentProperties addRegisteredDirectory: aRepository repositoryDirectory / 'lepiter'.
			defaultDatabase reload ]
		ifNone: [
			self inform: 'Repository not found.' ]
]

{ #category : 'baselines' }
BaselineOfGt4GlassCase >> baseline: spec [
	<baseline>
	^ spec for: #common do: [
		"Gt4HuggingFace is Gc-agnostic and extractable to its own repo; the core depends on it only through the adapter package."
		spec package: 'Gt4HuggingFace'.
		spec package: 'Gt4GlassCase'.
		spec
			package: 'Gt4GlassCase-HuggingFace'
			with: [ spec requires: #('Gt4GlassCase' 'Gt4HuggingFace') ] ]
]
