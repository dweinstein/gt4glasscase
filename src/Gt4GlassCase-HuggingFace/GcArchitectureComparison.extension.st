Extension { #name : 'GcArchitectureComparison' }

{ #category : '*Gt4GlassCase-HuggingFace' }
GcArchitectureComparison class >> forRepositories: aCollectionOfRepoIds [
	"Fetches one config.json per repo over HTTP."
	| labeled |
	labeled := aCollectionOfRepoIds collect: [ :repoId |
		repoId -> (GcHuggingFaceModelSource forRepository: repoId) architecture ].
	^ self forAll: labeled
]
