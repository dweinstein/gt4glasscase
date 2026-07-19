"
A dispatched unit of work. A GcJob BECOMES its result: inspect it running -> live log tail; come back done -> the same view is the completion group.
"
Class {
	#name : 'GcJob',
	#superclass : 'Object',
	#instVars : [
		'spec',
		'status',
		'backend',
		'remoteId',
		'submittedAt',
		'completedAt',
		'cost',
		'resultHandle',
		'logs'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}
