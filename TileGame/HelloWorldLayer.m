#import "HelloWorldLayer.h"
#import "AppDelegate.h"
#import "SimpleAudioEngine.h"
#import "GameOverScene.h"


@interface HudLayer ()
@property (unsafe_unretained) HelloWorldLayer *gameLayer;
@end

@implementation HudLayer
{
    CCLabelTTF *_label;
}

- (id)init
{
    self = [super init];
    if (self) {
        CGSize winSize = [[CCDirector sharedDirector] winSize];
        _label = [CCLabelTTF labelWithString:@"0" fontName:@"Verdana-Bold" fontSize:18.0];
        _label.color = ccc3(0,0,0);
        int margin = 10;
        _label.position = ccp(winSize.width - (_label.contentSize.width/2) - margin, _label.contentSize.height/2 + margin);
        [self addChild:_label];
        
        
        // define the button
        CCMenuItem *on;
        CCMenuItem *off;
        
        on = [CCMenuItemImage itemWithNormalImage:@"projectile-button-on.png"
                                    selectedImage:@"projectile-button-on.png" target:nil selector:nil];
        off = [CCMenuItemImage itemWithNormalImage:@"projectile-button-off.png"
                                     selectedImage:@"projectile-button-off.png" target:nil selector:nil];
        
        CCMenuItemToggle *toggleItem = [CCMenuItemToggle itemWithTarget:self
                                                               selector:@selector(projectileButtonTapped:) items:off, on, nil];
        CCMenu *toggleMenu = [CCMenu menuWithItems:toggleItem, nil];
        toggleMenu.position = ccp(100, 32);
        [self addChild:toggleMenu];

    }
    return self;
}

-(void)numCollectedChanged:(int)numCollected
{
    _label.string = [NSString stringWithFormat:@"%d",numCollected];
}

// callback for the button
// mode 0 = moving mode
// mode 1 = ninja star throwing mode
- (void)projectileButtonTapped:(id)sender
{
    if (_gameLayer.mode == 1) {
        _gameLayer.mode = 0;
    } else {
        _gameLayer.mode = 1;
    }
}

@end


@interface HelloWorldLayer()

@property (strong) CCTMXTiledMap *tileMap;
@property (strong) CCTMXLayer *background;
@property (strong) CCSprite *player;
@property (strong) CCTMXLayer *meta;
@property (strong) CCTMXLayer *foreground;
@property (strong) HudLayer *hud;
@property (assign) int numCollected;

@property (strong) NSMutableArray *enemies;
@property (strong) NSMutableArray *projectiles;


@end

@implementation HelloWorldLayer

// Helper class method that creates a Scene with the HelloWorldLayer as the only child.
+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
    
	// 'layer' is an autorelease object.
	HelloWorldLayer *layer = [HelloWorldLayer node];
    
	// add layer as a child to scene
	[scene addChild: layer];
    
    HudLayer *hud = [HudLayer node];
    [scene addChild:hud];
    layer.hud = hud;
    
    hud.gameLayer = layer;
    
	// return the scene
	return scene;
}

-(id) init
{
	if( (self=[super init]) ) {
        
        // At top of init for HelloWorldLayer
        [[SimpleAudioEngine sharedEngine] preloadEffect:@"pickup.caf"];
        [[SimpleAudioEngine sharedEngine] preloadEffect:@"hit.caf"];
        [[SimpleAudioEngine sharedEngine] preloadEffect:@"move.caf"];
        [[SimpleAudioEngine sharedEngine] playBackgroundMusic:@"TileMap.caf"];
        
        self.tileMap = [CCTMXTiledMap tiledMapWithTMXFile:@"TileMap.tmx"];
        self.background = [_tileMap layerNamed:@"Background"];
        self.foreground = [_tileMap layerNamed:@"Foreground"];
        
        self.meta = [_tileMap layerNamed:@"Meta"];
        _meta.visible = NO;
        
        CCTMXObjectGroup *objectGroup = [_tileMap objectGroupNamed:@"Objects"];
        NSAssert(objectGroup != nil, @"tile map has no objects object layer");
        
        NSDictionary *spawnPoint = [objectGroup objectNamed:@"SpawnPoint"];
        int x = [spawnPoint[@"x"] integerValue];
        int y = [spawnPoint[@"y"] integerValue];
        
        _player = [CCSprite spriteWithFile:@"Player.png"];
        _player.position = ccp(x,y);
        
        [self addChild:_player];
        [self setViewPointCenter:_player.position];
        
        [self addChild:_tileMap z:-1];
        
        self.touchEnabled = YES;
        
        self.enemies = [[NSMutableArray alloc] init];
        self.projectiles = [[NSMutableArray alloc] init];
        [self schedule:@selector(testCollisions:)];
        
        for (spawnPoint in [objectGroup objects]) {
            if ([[spawnPoint valueForKey:@"Enemy"] intValue] == 1){
                x = [[spawnPoint valueForKey:@"x"] intValue];
                y = [[spawnPoint valueForKey:@"y"] intValue];
                [self addEnemyAtX:x y:y];
            }
        }
        
        _mode = 0;
    }
    return self;
}

- (void)setViewPointCenter:(CGPoint) position {
    
    CGSize winSize = [CCDirector sharedDirector].winSize;
    
    int x = MAX(position.x, winSize.width/2);
    int y = MAX(position.y, winSize.height/2);
    x = MIN(x, (_tileMap.mapSize.width * _tileMap.tileSize.width) - winSize.width / 2);
    y = MIN(y, (_tileMap.mapSize.height * _tileMap.tileSize.height) - winSize.height/2);
    CGPoint actualPosition = ccp(x, y);
    
    CGPoint centerOfView = ccp(winSize.width/2, winSize.height/2);
    CGPoint viewPoint = ccpSub(centerOfView, actualPosition);
    self.position = viewPoint;
}

#pragma mark - handle touches
-(void)registerWithTouchDispatcher
{
    [[[CCDirector sharedDirector] touchDispatcher] addTargetedDelegate:self
                                                              priority:0
                                                       swallowsTouches:YES];
}

-(BOOL) ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event
{
	return YES;
}

- (void) win {
    GameOverScene *gameOverScene = [GameOverScene node];
    [gameOverScene.layer.label setString:@"You Win!"];
    [[CCDirector sharedDirector] replaceScene:gameOverScene];
}

-(void)setPlayerPosition:(CGPoint)position {
	
    CGPoint tileCoord = [self tileCoordForPosition:position];
    int tileGid = [_meta tileGIDAt:tileCoord];
    if (tileGid) {
        NSDictionary *properties = [_tileMap propertiesForGID:tileGid];
        if (properties) {
            
            NSString *collision = properties[@"Collidable"];
            if (collision && [collision isEqualToString:@"True"]) {
                [[SimpleAudioEngine sharedEngine] playEffect:@"hit.caf"];
                return;
            }
            
            NSString *collectible = properties[@"Collectable"];
            if (collectible && [collectible isEqualToString:@"True"]) {
                [[SimpleAudioEngine sharedEngine] playEffect:@"pickup.caf"];
                self.numCollected++;
                [_hud numCollectedChanged:_numCollected];
                
                if (self.numCollected == 6) {
                    [self win];
                }
                
                [_meta removeTileAt:tileCoord];
                [_foreground removeTileAt:tileCoord];
            }
        }
    }
    [[SimpleAudioEngine sharedEngine] playEffect:@"move.caf"];
    _player.position = position;    
}

-(void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event
{
    if (_mode == 0) {

        CGPoint touchLocation = [touch locationInView:touch.view];
        touchLocation = [[CCDirector sharedDirector] convertToGL:touchLocation];
        touchLocation = [self convertToNodeSpace:touchLocation];
        
        CGPoint playerPos = _player.position;
        CGPoint diff = ccpSub(touchLocation, playerPos);
        
        if ( abs(diff.x) > abs(diff.y) ) {
            if (diff.x > 0) {
                playerPos.x += _tileMap.tileSize.width;
            } else {
                playerPos.x -= _tileMap.tileSize.width;
            }
        } else {
            if (diff.y > 0) {
                playerPos.y += _tileMap.tileSize.height;
            } else {
                playerPos.y -= _tileMap.tileSize.height;
            }
        }
        
        CCLOG(@"playerPos %@",CGPointCreateDictionaryRepresentation(playerPos));
        
        // safety check on the bounds of the map
        if (playerPos.x <= (_tileMap.mapSize.width * _tileMap.tileSize.width) &&
            playerPos.y <= (_tileMap.mapSize.height * _tileMap.tileSize.height) &&
            playerPos.y >= 0 &&
            playerPos.x >= 0 )
        {
            [self setPlayerPosition:playerPos];
        }
        
        [self setViewPointCenter:_player.position];

    } else {
        // Find where the touch is
        CGPoint touchLocation = [touch locationInView: [touch view]];
        touchLocation = [[CCDirector sharedDirector] convertToGL: touchLocation];
        touchLocation = [self convertToNodeSpace:touchLocation];
        
        // Create a projectile and put it at the player's location
        CCSprite *projectile = [CCSprite spriteWithFile:@"Projectile.png"];
        projectile.position = _player.position;
        [self addChild:projectile];
        
        // Determine where we wish to shoot the projectile to
        int realX;
        
        // Are we shooting to the left or right?
        CGPoint diff = ccpSub(touchLocation, _player.position);
        if (diff.x > 0)
        {
            realX = (_tileMap.mapSize.width * _tileMap.tileSize.width) +
            (projectile.contentSize.width/2);
        } else {
            realX = -(_tileMap.mapSize.width * _tileMap.tileSize.width) -
            (projectile.contentSize.width/2);
        }
        float ratio = (float) diff.y / (float) diff.x;
        int realY = ((realX - projectile.position.x) * ratio) + projectile.position.y;
        CGPoint realDest = ccp(realX, realY);
        
        // Determine the length of how far we're shooting
        int offRealX = realX - projectile.position.x;
        int offRealY = realY - projectile.position.y;
        float length = sqrtf((offRealX*offRealX) + (offRealY*offRealY));
        float velocity = 480/1; // 480pixels/1sec
        float realMoveDuration = length/velocity;
        
        // Move projectile to actual endpoint
        id actionMoveDone = [CCCallFuncN actionWithTarget:self
                                                 selector:@selector(projectileMoveFinished:)];
        [projectile runAction:
         [CCSequence actionOne:
          [CCMoveTo actionWithDuration: realMoveDuration
                              position: realDest]
                           two: actionMoveDone]];
        
        [self.projectiles addObject:projectile];
    }

}

- (CGPoint)tileCoordForPosition:(CGPoint)position {
    int x = position.x / _tileMap.tileSize.width;
    int y = ((_tileMap.mapSize.height * _tileMap.tileSize.height) - position.y) / _tileMap.tileSize.height;
    return ccp(x, y);
}


-(void)addEnemyAtX:(int)x y:(int)y {
    CCSprite *enemy = [CCSprite spriteWithFile:@"enemy1.png"];
    enemy.position = ccp(x, y);
    [self addChild:enemy];
    
    // Use our animation method and
    // start the enemy moving toward the player
    [self animateEnemy:enemy];

    [self.enemies addObject:enemy];
}

// callback. starts another iteration of enemy movement.
- (void) enemyMoveFinished:(id)sender {
    CCSprite *enemy = (CCSprite *)sender;
    
    [self animateEnemy: enemy];
}

// a method to move the enemy 10 pixels toward the player
- (void) animateEnemy:(CCSprite*)enemy
{
    // speed of the enemy
    ccTime actualDuration = 0.3;
    
    // immediately before creating the actions in animateEnemy
    // rotate to face the player
    CGPoint diff = ccpSub(_player.position,enemy.position);
    float angleRadians = atanf((float)diff.y / (float)diff.x);
    float angleDegrees = CC_RADIANS_TO_DEGREES(angleRadians);
    float cocosAngle = -1 * angleDegrees;
    if (diff.x < 0) {
        cocosAngle += 180;
    }
    enemy.rotation = cocosAngle;

    
    // Create the actions
    id actionMove = [CCMoveBy actionWithDuration:actualDuration
                                        position:ccpMult(ccpNormalize(ccpSub(_player.position,enemy.position)), 10)];
    id actionMoveDone = [CCCallFuncN actionWithTarget:self
                                             selector:@selector(enemyMoveFinished:)];
    [enemy runAction:
     [CCSequence actions:actionMove, actionMoveDone, nil]];
}

- (void) projectileMoveFinished:(id)sender {
    CCSprite *sprite = (CCSprite *)sender;
    [self removeChild:sprite cleanup:YES];

    [self.projectiles removeObject:sprite];
}


- (void)testCollisions:(ccTime)dt {
    
    NSMutableArray *projectilesToDelete = [[NSMutableArray alloc] init];
    
    // iterate through projectiles
    for (CCSprite *projectile in self.projectiles) {
        CGRect projectileRect = CGRectMake(
                                           projectile.position.x - (projectile.contentSize.width/2),
                                           projectile.position.y - (projectile.contentSize.height/2),
                                           projectile.contentSize.width,
                                           projectile.contentSize.height);
        
        NSMutableArray *targetsToDelete = [[NSMutableArray alloc] init];
        
        // iterate through enemies, see if any intersect with current projectile
        for (CCSprite *target in self.enemies) {
            CGRect targetRect = CGRectMake(
                                           target.position.x - (target.contentSize.width/2),
                                           target.position.y - (target.contentSize.height/2),
                                           target.contentSize.width,
                                           target.contentSize.height);
            
            if (CGRectIntersectsRect(projectileRect, targetRect)) {
                [targetsToDelete addObject:target];
            }
        }
        
        // delete all hit enemies
        for (CCSprite *target in targetsToDelete) {
            [self.enemies removeObject:target];
            [self removeChild:target cleanup:YES];
        }
        
        if (targetsToDelete.count > 0) {
            // add the projectile to the list of ones to remove
            [projectilesToDelete addObject:projectile];
        }
    }
    
    // remove all the projectiles that hit.
    for (CCSprite *projectile in projectilesToDelete) {
        [self.projectiles removeObject:projectile];
        [self removeChild:projectile cleanup:YES];
    }
}


@end