//
//  GameOverScene.h
//  TileGame
//
//  Copyright (c) 2013 Geek & Dad, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "cocos2d.h"

@interface GameOverLayer : CCLayerColor {
}
@property (nonatomic, strong) CCLabelTTF *label;
@end

@interface GameOverScene : CCScene {
}
@property (nonatomic, strong) GameOverLayer *layer;
@end
