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

{ #category : 'baseline' }
BaselineOfGt4GlassCase >> baseline: spec [
	<baseline>
		^ spec for: #common do: [
			spec package: 'Gt4GlassCase'
		]
]
