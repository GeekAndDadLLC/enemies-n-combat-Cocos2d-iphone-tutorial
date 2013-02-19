//
//  GameOverScene.m
//  TileGame
//
//  Copyright (c) 2013 Geek & Dad, LLC. All rights reserved.
//

#import "GameOverScene.h"
#import "HelloWorldLayer.h"

@implementation GameOverScene

- (id)init {
    
    if ((self = [super init])) {
        self.layer = [GameOverLayer node];
        [self addChild:_layer];
    }
    return self;
}

@end

@implementation GameOverLayer

-(id) init
{
    if( (self=[super initWithColor:ccc4(255,255,255,255)] )) {
        
        CGSize winSize = [[CCDirector sharedDirector] winSize];
        self.label = [CCLabelTTF labelWithString:@"" fontName:@"Arial" fontSize:32];
        _label.color = ccc3(0,0,0);
        _label.position = ccp(winSize.width/2, winSize.height/2);
        [self addChild:_label];
        
        [self runAction:[CCSequence actions:
                         [CCDelayTime actionWithDuration:3],
                         [CCCallFunc actionWithTarget:self selector:@selector(gameOverDone)],
                         nil]];
        
    }
    return self;
}

- (void)gameOverDone {
    
    [[CCDirector sharedDirector] replaceScene:[HelloWorldLayer scene]];
    
}

@end
