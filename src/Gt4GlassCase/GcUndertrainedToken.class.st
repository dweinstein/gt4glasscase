"
A token suspected undertrained on embedding-norm evidence (needs weights). Intended to wrap a GcVocabToken — an undertrained token IS a vocab token plus an anomaly verdict — rather than re-model id and text; GcVocabToken carries the metadata-only anomaly flags.
"
Class {
	#name : 'GcUndertrainedToken',
	#superclass : 'Object',
	#instVars : [
		'tokenId',
		'text',
		'embeddingNorm',
		'score'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}
