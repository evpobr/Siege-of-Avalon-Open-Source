unit ObjInventory;

{$MODE Delphi}

{******************************************************************************}
{                                                                              }
{               Siege Of Avalon : Open Source Edition                          }
{               -------------------------------------                          }
{                                                                              }
{ Portions created by Digital Tome L.P. Texas USA are                          }
{ Copyright ©1999-2000 Digital Tome L.P. Texas USA                             }
{ All Rights Reserved.                                                         }
{                                                                              }
{ Portions created by Team SOAOS are                                           }
{ Copyright (C) 2003 - Team SOAOS.                                             }
{                                                                              }
{                                                                              }
{ Contributor(s)                                                               }
{ --------------                                                               }
{ Dominique Louis <Dominique@SavageSoftware.com.au>                            }
{                                                                              }
{                                                                              }
{                                                                              }
{ You may retrieve the latest version of this file at the SOAOS project page : }
{   http://www.sourceforge.com/projects/soaos                                  }
{                                                                              }
{ The contents of this file maybe used with permission, subject to             }
{ the GNU Lesser General Public License Version 2.1 (the "License"); you may   }
{ not use this file except in compliance with the License. You may             }
{ obtain a copy of the License at                                              }
{ http://www.opensource.org/licenses/lgpl-license.php                          }
{                                                                              }
{ Software distributed under the License is distributed on an                  }
{ "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or               }
{ implied. See the License for the specific language governing                 }
{ rights and limitations under the License.                                    }
{                                                                              }
{ Description                                                                  }
{ -----------                                                                  }
{                                                                              }
{                                                                              }
{                                                                              }
{                                                                              }
{                                                                              }
{                                                                              }
{                                                                              }
{ Requires                                                                     }
{ --------                                                                     }
{   DirectX Runtime libraris on Win32                                          }
{   They are available from...                                                 }
{   http://www.microsoft.com.                                                  }
{                                                                              }
{ Programming Notes                                                            }
{ -----------------                                                            }
{                                                                              }
{                                                                              }
{                                                                              }
{                                                                              }
{ Revision History                                                             }
{ ----------------                                                             }
{   July    13 2003 - DL : Initial Upload to CVS                               }
{                                                                              }
{******************************************************************************}

{$INCLUDE Anigrp30cfg.inc}

interface

uses
{$IFDEF DirectX}
  DirectX,
  DXUtil,
  DXEffects,
{$ENDIF}
  Windows,
  SysUtils,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  ExtCtrls,
  CharacterAI,
  Resource,
  GameText,
  Display,
  Parts,
  Scroll,
  Anigrp30,
  LogFile,
  Engine;

type

  pTempItems = ^TemItems;
  TemItems = record
    PItem : TItem; //pointer to the item
    InvX : Integer;
    InvY : Integer;
    W : Integer;
    H : Integer;
    CharacterHadThisOnHim : boolean;
    WhoHasThis : integer; //whos got this item? Left guy(1), right guy(2) (or container) or ground(3)?
    DXSurface : IDirectDrawSurface; //barbie graphic surface
    DXSurfaceIcon : IDirectDrawSurface; //icon graphic surface
    DXShadow : IDirectDrawSurface; //The shadow
  end;

  TObjInventory = class( TDisplay )
  private
    CheckForGroundDrop : boolean;
    PlotArray : array[ 0..11, 0..13 ] of integer;
    PlotArray2 : array[ 0..20, 0..20 ] of integer;
    BMBack : TBitmap; //The inventory screen bitmap used for loading
    ItemList : TList; //the list of items
    pInventoryItem : pTempItems; //The temporary inventory and equipment items combined
    CurrentSelectedItem : Integer; //Current Item being dragged about
    Tx, Ty : Integer; // x and y locs used with the offset of the dragged item
{$IFDEF DirectX}
    DXBack : IDirectDrawSurface; //DD surface that holds the inventory screen before blit
    DxDirty : IDirectDrawSurface; //DD for cleanup when dragging items
    DXLeftArrow : IDirectDrawSurface; //Inventory left arrow
    DXRightArrow : IDirectDrawSurface; //Inventory right arrow
    DXBackToGame : IDirectDrawSurface; //Back To Game highlight
    DXLeftAll : IDirectDrawSurface; //Move all from left to right arrow
    DXRightAll : IDirectDrawSurface; //Move all form right ot left arrow
    DXBrown : IDirectDrawSurface;
{$ENDIF}
    GroundOrderList : TList; //used to keep track of the order of items on the ground
    TopGroundIndex : Integer; //Index of the current top ground item
    Alpha : integer;
    DlgScroll : TScroll; //the statistics scroll;
    GridRightMinX : integer; //The right grid's minX - used to handle drops, clicks
    GridRightMaxX : integer; //The right grid's maX
    GridRightMinY : integer; //The right grid's minY
    GridRightMaxY : integer; //The right grid's maxY
    ShadowAlpha : integer;
    txtMessage : array[ 0..7 ] of string;
    procedure ContainCursor( Action : integer ); //lock curson to screen during item drag
    function CollisionCheck( X, Y : Integer ) : Boolean;
    function GetSlotText : string;
    procedure BuildGrid; //Build the drop on grid for the right inv area
    procedure WriteTheInventoryData;
    procedure ShowOpenInventorySlots;
    function DropAnItem( X, Y : integer ) : boolean;
    procedure MoveAll( Source, Destination : integer ); //move as much of players inventory into object2 inventory as we can
    {procedure DebugPlot(i: integer);    }
  protected
    procedure MouseDown( Sender : TAniview; Button : TMouseButton;
      Shift : TShiftState; X, Y : Integer; GridX, GridY : integer ); override;
    procedure MouseMove( Sender : TAniview;
      Shift : TShiftState; X, Y : Integer; GridX, GridY : integer ); override;
    procedure MouseUp( Sender : TAniview; Button : TMouseButton;
      Shift : TShiftState; X, Y : Integer; GridX, GridY : integer ); override;
  public
    Character : TCharacter; //the charachter we draw inventory from to fill left box
    OtherOb : TSpriteObject; //Tcharacter; //Either use this or
    //Container: TContainer; //this- we load the right box based on which isn't nil
    GroundList : TList; //Passed to us - list of items on the ground
    constructor Create;
    destructor Destroy; override;
    procedure Paint; override;
    procedure Init; override;
    procedure Release; override;
  end;
implementation
uses
  AniDemo;
{ TObjInventory }

const
  LrgMsg = 437;
  SmlMsg = 415;
  ClearTop = SmlMsg;
  ClearBottom = 462;
  ClearLeft = 20;
  ClearRight = 590;


constructor TObjInventory.Create;
const
  FailName : string = 'TObjInventory.Create';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  try

    inherited;
    GroundList := TList.Create;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end;

destructor TObjInventory.Destroy;
const
  FailName : string = 'TObjInventory.Destroy';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  try

    GroundList.Free;
    GroundList := nil;
    inherited;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end;

procedure TObjInventory.Init;
var
  InvisColor : Integer; //Transparent color :RGB(0,255,255)
  i : Integer;
  DXBorder : IDirectDrawSurface;
  GreatestWidth, GreatestHeight : integer; //used to create the dirty rect surface
const
  FailName : string = 'TObjInventory.init';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  try

    if Loaded then
      Exit;
    inherited;
    MouseCursor.Cleanup;
    lpDDSBack.BltFast( 0, 0, lpDDSFront, Rect( 0, 0, ResWidth, ResHeight ), DDBLTFAST_NOCOLORKEY or DDBLTFAST_WAIT );
    MouseCursor.PlotDirty := false;

    ExText.Open( 'ObjInventory' );
    for i := 0 to 7 do
      txtMessage[ i ] := ExText.GetText( 'Message' + inttostr( i ) );


    CheckForGroundDrop := false;
    ShadowAlpha := 150;
    DlgScroll := TScroll.create; //create the statistics scroll
    DlgScroll.pText := pText; //assign the pointer to pText;
    pText.LoadFontGraphic( 'inventory' ); //load the inventory font graphic in
    pText.LoadTinyFontGraphic;
    CurrentSelectedItem := -1; //We aren't dragging anything
    DlgScroll.ScrollIsShowing := False; //stats screen isnt showing
    Alpha := 220; //alpha value for all alphabet plots
    BMBack := TBitmap.Create;
  //transparent color
    InvisColor := $00FFFF00;

  //We have to do this part up here in order to get coordinated from buildgrid
    BMBack.LoadFromFile( InterfacePath + 'merBackHighlight.bmp' );
    DXBrown := DDGetImage( lpDD, BMBack, InvisColor, False );

    BMBack.LoadFromFile( InterfacePath + 'invRightArrow.bmp' );
    DXRightArrow := DDGetImage( lpDD, BMBack, InvisColor, False );
    BMBack.LoadFromFile( InterfacePath + 'invLeftArrow.bmp' );
    DXLeftArrow := DDGetImage( lpDD, BMBack, InvisColor, False );
    BMBack.LoadFromFile( InterfacePath + 'obInvBackToGame.bmp' );
    DXBackToGame := DDGetImage( lpDD, BMBack, InvisColor, False );
    BMBack.LoadFromFile( InterfacePath + 'obInvRightAll.bmp' );
    DXRightAll := DDGetImage( lpDD, BMBack, InvisColor, False );
    BMBack.LoadFromFile( InterfacePath + 'obInvLeftAll.bmp' );
    DXLeftAll := DDGetImage( lpDD, BMBack, InvisColor, False );
    BMBack.LoadFromFile( InterfacePath + 'obInvCharacterToObjectInventory.bmp' );
    DXBack := DDGetImage( lpDD, BMBack, InvisColor, False );
  //DxDirty := DDGetImage(lpDD, BMBack, InvisColor, False); //for now this is how we will do it
  //build the left side inventory space
    BuildGrid;
  //now we blit the screen to the backbuffer
    lpDDSBack.BltFast( 0, 0, DXBack, Rect( 0, 0, BMBack.width, BMBack.Height ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
  //Now for the Alpha'ed edges
    BMBack.LoadFromFile( InterfacePath + 'obInvRightShadow.bmp' );
    DXBorder := DDGetImage( lpDD, BMBack, InvisColor, False );
    DrawSub( lpDDSBack, Rect( 659, 0, 659 + BMBack.Width, BMBack.Height ), Rect( 0, 0, BMBack.Width, BMBack.Height ), DXBorder, True, Alpha );

    DXBorder := nil;

    BMBack.LoadFromFile( InterfacePath + 'obInvBottomShadow.bmp' );
    DXBorder := DDGetImage( lpDD, BMBack, InvisColor, False );
    DrawSub( lpDDSBack, Rect( 0, 456, BMBack.Width, 456 + BMBack.Height ), Rect( 0, 0, BMBack.Width, BMBack.Height ), DXBorder, True, Alpha );

    DXBorder := nil; //release DXBorder

  //Now put the names up
    pText.PlotTextCentered( Character.name, 27, 243, 10, Alpha );
    if OtherOb is TCharacter then
      pText.PlotTextCentered( TCharacter( OtherOb ).name, 417, 633, 10, Alpha )
    else
      pText.PlotTextCentered( TContainer( OtherOb ).name, 417, 633, 10, Alpha );


  //Create list
    ItemList := TList.Create; //create the ItemList
    GroundOrderList := TList.Create; //and the ground orderlist
  //Load path info, coords into temp objects from the Character's Inventory
    for i := 0 to Character.Inventory.Count - 1 do
    begin
      New( pInventoryItem );
      pInventoryItem.PItem := Character.Inventory.Items[ i ];
      pInventoryItem.InvX := TItem( Character.Inventory.Items[ i ] ).InvX * 18 + 27;
      pInventoryItem.InvY := TItem( Character.Inventory.Items[ i ] ).InvY * 26 + 42;
      pInventoryItem.WhoHasThis := 1; //the character on the left; the instigating char
      pInventoryItem.CharacterHadThisOnHim := true;
      ItemList.Add( pInventoryItem );
    end;
    if OtherOb is TCharacter then
    begin
      //Load path info, coords into temp objects from the Character's Inventory
      for i := 0 to TCharacter( OtherOb ).Inventory.Count - 1 do
      begin
        New( pInventoryItem );
        pInventoryItem.PItem := TCharacter( OtherOb ).Inventory.Items[ i ];
        pInventoryItem.InvX := TItem( TCharacter( OtherOb ).Inventory.Items[ i ] ).InvX * 18 + 418;
        pInventoryItem.InvY := TItem( TCharacter( OtherOb ).Inventory.Items[ i ] ).InvY * 26 + 42;
        pInventoryItem.WhoHasThis := 2; //the character/container on the right;
        ItemList.Add( pInventoryItem );
      end;
    end
    else if OtherOb is TContainer then
    begin
      //Load path info, coords into temp objects from the Character's Inventory
      for i := 0 to TContainer( OtherOb ).Inventory.Count - 1 do
      begin
        New( pInventoryItem );
        pInventoryItem.PItem := TContainer( OtherOb ).Inventory.Items[ i ];
        pInventoryItem.InvX := TItem( TContainer( OtherOb ).Inventory.Items[ i ] ).InvX * 18 + GridRightMinX;
        pInventoryItem.InvY := TItem( TContainer( OtherOb ).Inventory.Items[ i ] ).InvY * 26 + GridRightMinY;
        pInventoryItem.WhoHasThis := 2; //the container on the right;
        ItemList.Add( pInventoryItem );
      end;
    end;
  //Now the ground
    for i := 0 to GroundList.Count - 1 do
    begin
      New( pInventoryItem );
      pInventoryItem.PItem := GroundList.Items[ i ];
      if i = 0 then
      begin
        pInventoryItem.InvX := 288; //325-pInventoryItem.pItem.width div 2;       //Only the first ground item is visible
        pInventoryItem.InvY := 377; //391-pInventoryItem.pItem.height div 2;
      end
      else
      begin
        pInventoryItem.InvX := 999; //set it offscreen so we dont see it
        pInventoryItem.InvY := 999;
      end;
      pInventoryItem.WhoHasThis := 3; //the ground has it
      ItemList.Add( pInventoryItem );
      GroundOrderList.Add( pInventoryItem ); //Now we create our order list
    end;

  //Get the barbie pics for all the items, as well as the GroundIcons
    GreatestWidth := GroundListWidth; //we inot to ground list size - must be at least this big
    GreatestHeight := GroundListHeight;
    for i := 0 to ItemList.Count - 1 do
    begin
      pTempItems( ItemList.Items[ i ] ).DXSurface := pTempItems( ItemList.Items[ i ] ).pItem.GetInventoryImage;
      pTempItems( ItemList.Items[ i ] ).DXSurfaceIcon := pTempItems( ItemList.Items[ i ] ).pItem.GetIconicImage;
      pTempItems( ItemList.Items[ i ] ).DXShadow := pTempItems( ItemList.Items[ i ] ).pItem.GetInventoryShadow;
      //pTempItems(ItemList.Items[i]).IW := pTempItems(ItemList.Items[i]).pItem.width; //icon width
      //pTempItems(ItemList.Items[i]).IH := pTempItems(ItemList.Items[i]).pItem.height;//icon height
      pTempItems( ItemList.Items[ i ] ).W := pTempItems( ItemList.Items[ i ] ).pItem.InvW * 18;
      pTempItems( ItemList.Items[ i ] ).H := pTempItems( ItemList.Items[ i ] ).pItem.InvH * 26;
      if pTempItems( ItemList.Items[ i ] ).W > GreatestWidth then
        GreatestWidth := pTempItems( ItemList.Items[ i ] ).W;
      if pTempItems( ItemList.Items[ i ] ).H > GreatestHeight then
        GreatestHeight := pTempItems( ItemList.Items[ i ] ).H;
    end;
  //Create the DirectRect fix surface
    DXDirty := DDGetSurface( lpDD, GreatestWidth, GreatestHeight, InvisColor, true );

{$IFDEF DirectX}
  //release the bitmap
    BMBack.Free;
  //Now plot all of the items on the grid
    for i := 0 to ItemList.Count - 1 do
    begin
      //lpDDSBack.BltFast(pTempItems(ItemList.Items[i]).InvX, pTempItems(ItemList.Items[i]).InvY, pTempItems(ItemList.Items[i]).DXSurface, Rect(0, 0, pTempItems(ItemList.Items[i]).W, pTempItems(ItemList.Items[i]).H), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT)
      if pTempItems( ItemList.Items[ i ] ).WhoHasThis <> 3 then
      begin //if not in the ground slot
        DrawSub( lpDDSBack, rect( pTempItems( ItemList.Items[ i ] ).InvX, pTempItems( ItemList.Items[ i ] ).InvY, pTempItems( ItemList.Items[ i ] ).InvX + pTempItems( ItemList.Items[ i ] ).W, pTempItems( ItemList.Items[ i ] ).InvY + pTempItems( ItemList.Items[ i ] ).H ), Rect( 0, 0, pTempItems( ItemList.Items[ i ] ).W, pTempItems( ItemList.Items[ i ] ).H ), pTempItems( ItemList.Items[ i ] ).DXShadow, True, ShadowAlpha );
        lpDDSBack.BltFast( pTempItems( ItemList.Items[ i ] ).InvX, pTempItems( ItemList.Items[ i ] ).InvY, pTempItems( ItemList.Items[ i ] ).DXSurface, Rect( 0, 0, pTempItems( ItemList.Items[ i ] ).W, pTempItems( ItemList.Items[ i ] ).H ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT )
      end
      else //In the ground slot so plot iconic image
        lpDDSBack.BltFast( pTempItems( ItemList.Items[ i ] ).InvX, pTempItems( ItemList.Items[ i ] ).InvY, pTempItems( ItemList.Items[ i ] ).DXSurfaceIcon, Rect( 0, 0, GroundListWidth, GroundListHeight ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
    end;
  //Whew! Now we flip it all to the screen
    lpDDSFront.Flip( nil, DDFLIP_WAIT );
    lpDDSBack.BltFast( 0, 0, lpDDSFront, Rect( 0, 0, 800, 600 ), DDBLTFAST_WAIT );
    MouseCursor.PlotDirty := false;
{$ENDIF}
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //TObjInventory.Init

procedure TObjInventory.MouseDown( Sender : TAniview; Button : TMouseButton;
  Shift : TShiftState; X, Y, GridX, GridY : integer );
var
  i, j : integer;
  B1, B2, B3, B4, B5, B6 : Boolean;
  pTemp : Pointer;
  rRect : TRect;
  DontAllowDrop : boolean;
const
  FailName : string = 'TObjInventory.MouseDown';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  try

    if CurrentSelectedItem = -1 then
    begin //if no piece is being dragged pick one up
      if DlgScroll.ScrollIsShowing then
      begin
        if PtInRect( rect( 119, 30, 119 + 443, 30 + 90 ), point( X, Y ) ) or PtInRect( rect( 119, 373, 119 + 443, 373 + 70 ), point( X, Y ) ) then //or PtInRect(rect(171,50,171+338,380),point(X,Y)) then
        begin
          if Y < 248 then
          begin
            DlgScroll.ScrollAmount := 1;
            DlgScroll.KeepOnScrolling := true;
            DlgScroll.ScrollStatsScroll;
          end
          else
          begin
            DlgScroll.ScrollAmount := -1;
            DlgScroll.KeepOnScrolling := true;
            DlgScroll.ScrollStatsScroll;
          end
        end
        else
        begin
          DlgScroll.KeepOnScrolling := false;
          DlgScroll.ScrollIsShowing := False;
          Paint;
        end;
      end
      else if ( X > 595 ) and ( X < 668 ) and ( Y > 418 ) and ( Y < 463 ) then
      begin //they hit the back to button
      //WriteTheInventoryData;            //write the data back
        Close; //lose the screen
      end
      else if ( X > 300 ) and ( X < 344 ) and ( Y > 197 ) and ( Y < 214 ) then
      begin //Move all from left to right
        MoveAll( 1, 2 ); //move all items from player to object/player2
      end
      else if ( X > 304 ) and ( X < 343 ) and ( Y > 224 ) and ( Y < 243 ) then
      begin //Move all from right to left
        MoveAll( 2, 1 ); //move all items from object/player2 to Player
      end
      else if ( X > 271 ) and ( X < 287 ) and ( Y > 375 ) and ( Y < 407 ) then
      begin //left arrow for ground
        if GroundOrderList.Count > 1 then
        begin //get the prev item on the ground and show it
          j := TopGroundIndex;
          if j <> 0 then
          begin //if its not the first item in the list
          //replace the back from the DXBack buffer.
          //lpDDSBack.BltFast(pTempItems(GroundOrderList.Items[j]).InvX, pTempItems(GroundOrderList.Items[j]).InvY, DXBack, Rect(pTempItems(GroundOrderList.Items[j]).InvX, pTempItems(GroundOrderList.Items[j]).InvY, pTempItems(GroundOrderList.Items[j]).InvX + pTempItems(GroundOrderList.Items[j]).W, pTempItems(GroundOrderList.Items[j]).InvY + pTempItems(GroundOrderList.Items[j]).H), DDBLTFAST_WAIT);
            lpDDSBack.BltFast( 287, 376, DXBack, Rect( 287, 376, 363, 406 ), DDBLTFAST_WAIT );
            pTempItems( GroundOrderList.Items[ j ] ).InvX := 999;
            pTempItems( GroundOrderList.Items[ j ] ).InvY := 999;
            j := j - 1;
          //Set the coordinates of the new item and Plot it
            pTempItems( GroundOrderList.Items[ j ] ).InvX := 288; //325-pTempItems(GroundOrderList.Items[j]).IW div 2;
            pTempItems( GroundOrderList.Items[ j ] ).InvY := 377; //391-pTempItems(GroundOrderList.Items[j]).IH div 2;
            lpDDSBack.BltFast( pTempItems( GroundOrderList.Items[ j ] ).InvX, pTempItems( GroundOrderList.Items[ j ] ).InvY, pTempItems( GroundOrderList.Items[ j ] ).DXSurfaceIcon, Rect( 0, 0, GroundListWidth, GroundListHeight ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
            TopGroundIndex := j;
          //DebugPlot(TopGroundIndex);
          end
          else
          begin
          //making an obnoxious buzzing noise? - we cant go backwards from the first item
          end;
        end;
      end
      else if ( X > 364 ) and ( X < 376 ) and ( Y > 375 ) and ( Y < 407 ) then
      begin //right arrow for ground
        if GroundOrderList.Count > 1 then
        begin //get the Next item on the ground and show it
          j := TopGroundIndex;
          if j < ( GroundOrderList.Count - 1 ) then
          begin //if its not the last item in the list
          //replace the back from the DXBack buffer.
          //lpDDSBack.BltFast(pTempItems(GroundOrderList.Items[j]).InvX, pTempItems(GroundOrderList.Items[j]).InvY, DXBack, Rect(pTempItems(GroundOrderList.Items[j]).InvX, pTempItems(GroundOrderList.Items[j]).InvY, pTempItems(GroundOrderList.Items[j]).InvX + pTempItems(GroundOrderList.Items[j]).W, pTempItems(GroundOrderList.Items[j]).InvY + pTempItems(GroundOrderList.Items[j]).H), DDBLTFAST_WAIT);
            lpDDSBack.BltFast( 287, 376, DXBack, Rect( 287, 376, 363, 406 ), DDBLTFAST_WAIT );
            pTempItems( GroundOrderList.Items[ j ] ).InvX := 999;
            pTempItems( GroundOrderList.Items[ j ] ).InvY := 999;
            j := j + 1;
          //Set the coordinates of the new item and Plot it
            pTempItems( GroundOrderList.Items[ j ] ).InvX := 288; //325-pTempItems(GroundOrderList.Items[j]).IW div 2;
            pTempItems( GroundOrderList.Items[ j ] ).InvY := 377; //391-pTempItems(GroundOrderList.Items[j]).IH div 2;
            lpDDSBack.BltFast( pTempItems( GroundOrderList.Items[ j ] ).InvX, pTempItems( GroundOrderList.Items[ j ] ).InvY, pTempItems( GroundOrderList.Items[ j ] ).DXSurfaceIcon, Rect( 0, 0, GroundListWidth, GroundListHeight ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
            TopGroundIndex := j;
          //DebugPlot(TopGroundIndex);
          end
          else
          begin
          //making an obnoxious buzzing noise? - we cant go forwards from the last item
          end;
        end;
      end
      else if ( x > 287 ) and ( x < 376 ) and ( y > 363 ) and ( y < 406 ) and ( CurrentSelectedItem = -1 ) then
      begin //over the ground slot
        //If we are pulling this from the ground slot, pick a new top item
        if GroundOrderList.Count > 0 then
        begin
          CurrentSelectedItem := ItemList.IndexOf( GroundOrderList.items[ TopGroundIndex ] );
          if Button = mbRight then
          begin
            DlgScroll.OpenStatsScroll( pTempItems( ItemList.Items[ CurrentSelectedItem ] ).pItem );
            CurrentSelectedItem := -1;
          end
          else
          begin
            lpDDSBack.BltFast( 287, 376, DXBack, Rect( 287, 376, 363, 406 ), DDBLTFAST_WAIT ); //clean the box
            if GroundOrderList.Count > 1 then
            begin //get the next item on the ground and show it
              j := GroundOrderList.IndexOf( ItemList.Items[ CurrentSelectedItem ] );
              if ( j = ( GroundOrderList.Count - 1 ) ) then //if its the last item in the list
                j := 0 //set it to the first one
              else //set it to the item folowing this one
                j := j + 1;
              pTempItems( GroundOrderList.Items[ j ] ).InvX := 288; //325-pTempItems(GroundOrderList.Items[j]).IW div 2;
              pTempItems( GroundOrderList.Items[ j ] ).InvY := 377; //391-pTempItems(GroundOrderList.Items[j]).IH div 2;
              lpDDSBack.BltFast( pTempItems( GroundOrderList.Items[ j ] ).InvX, pTempItems( GroundOrderList.Items[ j ] ).InvY, pTempItems( GroundOrderList.Items[ j ] ).DXSurfaceIcon, Rect( 0, 0, GroundListWidth, GroundListHeight ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
              pTemp := GroundOrderList.Items[ j ]; //save the pointer to the new topmost item so we can do the delete and still track it
              GroundOrderList.Delete( GroundOrderList.IndexOf( ItemList.Items[ CurrentSelectedItem ] ) ); //remove this item from the GroundList pointer list
              TopGroundIndex := GroundOrderList.IndexOf( pTempItems( pTemp ) );
              //TopGroundIndex:=GroundOrderList.IndexOf(GroundOrderList.items[j]);
            end
            else
            begin
              GroundOrderList.Delete( GroundOrderList.IndexOf( ItemList.Items[ CurrentSelectedItem ] ) ); //remove this item from the GroundList pointer list
              TopGroundIndex := 0;
            end;
            //Compute the coords for the floating item
            Tx := ( X ) - pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W div 2;
            Ty := ( Y ) - pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H div 2;
            //Plot relevant text
            lpDDSBack.BltFast( ClearLeft, ClearTop, DXBack, Rect( ClearLeft, ClearTop, ClearRight, ClearBottom ), DDBLTFAST_WAIT ); //clean up before we plot test
            if UseSmallFont then
              pText.PlotTinyTextBlock( GetSlotText, ClearLeft, ClearRight, SmlMsg, Alpha )
            else
              pText.PlotText( GetSlotText, ClearLeft, LrgMsg, Alpha );
            //save the background to the dirty DD surface based on the floating item
            DXDirty.BltFast( 0, 0, lpDDSBack, Rect( Tx, Ty, Tx + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, Ty + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), DDBLTFAST_WAIT );
            //plot the item centered under the mouse pointer
            DrawSub( lpDDSBack, rect( Tx, Ty, Tx + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, Ty + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), Rect( 0, 0, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), pTempItems( ItemList.Items[ CurrentSelectedItem ] ).DXShadow, True, ShadowAlpha );
            lpDDSBack.BltFast( Tx, Ty, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).DXSurface, Rect( 0, 0, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
            ShowOpenInventorySlots;
            ContainCursor( 1 );
          end; //if Button = mbRight
        end //if GroundOrderList > 0
      end
      else
      begin //try to pick something up
        i := 0;
        while ( ( i < ItemList.Count ) and ( CurrentSelectedItem = -1 ) and Assigned( DXBack ) ) do
        begin
        //find the item the mouse is down over                                                                                                                                                                                                                                                        //not the ground
          if ( ( ( x ) >= pTempItems( ItemList.Items[ i ] ).InvX ) and ( ( x ) <= ( pTempItems( ItemList.Items[ i ] ).InvX + pTempItems( ItemList.Items[ i ] ).W ) ) and ( ( Y ) >= pTempItems( ItemList.Items[ i ] ).InvY ) and ( ( Y ) <= pTempItems( ItemList.Items[ i ] ).InvY + pTempItems( ItemList.Items[ i ] ).H ) and ( pTempItems( ItemList.Items[ i ] ).WhoHasThis < 3 ) ) then
          begin
            if Button = mbRight then
              DlgScroll.OpenStatsScroll( pTempItems( ItemList.Items[ i ] ).pItem )
            else
            begin
              CurrentSelectedItem := i; //Get the index of the selected item
            //replace the back from the DXBack buffer.
              lpDDSBack.BltFast( pTempItems( ItemList.Items[ i ] ).InvX, pTempItems( ItemList.Items[ i ] ).InvY, DXBack, Rect( pTempItems( ItemList.Items[ i ] ).InvX, pTempItems( ItemList.Items[ i ] ).InvY, pTempItems( ItemList.Items[ i ] ).InvX + pTempItems( ItemList.Items[ i ] ).W, pTempItems( ItemList.Items[ i ] ).InvY + pTempItems( ItemList.Items[ i ] ).H ), DDBLTFAST_WAIT );
            //Compute the coords for the floating item
              Tx := ( X ) - pTempItems( ItemList.Items[ i ] ).W div 2;
              Ty := ( Y ) - pTempItems( ItemList.Items[ i ] ).H div 2;
              if Tx < 0 then
                Tx := 0;
              if Ty < 0 then
                Ty := 0;
              if ( Tx + pTempItems( ItemList.Items[ i ] ).W ) > 659 then
                Tx := 659 - pTempItems( ItemList.Items[ i ] ).W;
              if ( Ty + pTempItems( ItemList.Items[ i ] ).H ) > 463 then
                Ty := 463 - pTempItems( ItemList.Items[ i ] ).H;
              ShowOpenInventorySlots;
            //save the background to the dirty DD surface based on the floating item
              DXDirty.BltFast( 0, 0, lpDDSBack, Rect( Tx, Ty, Tx + pTempItems( ItemList.Items[ i ] ).W, Ty + pTempItems( ItemList.Items[ i ] ).H ), DDBLTFAST_WAIT );
            //plot the item centered under the mouse pointer
              DrawSub( lpDDSBack, rect( Tx, Ty, Tx + pTempItems( ItemList.Items[ i ] ).W, Ty + pTempItems( ItemList.Items[ i ] ).H ), Rect( 0, 0, pTempItems( ItemList.Items[ i ] ).W, pTempItems( ItemList.Items[ i ] ).H ), pTempItems( ItemList.Items[ i ] ).DXShadow, True, ShadowAlpha );
              lpDDSBack.BltFast( Tx, Ty, pTempItems( ItemList.Items[ i ] ).DXSurface, Rect( 0, 0, pTempItems( ItemList.Items[ i ] ).W, pTempItems( ItemList.Items[ i ] ).H ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
              ContainCursor( 1 );
            //Plot relevant text
              lpDDSBack.BltFast( ClearLeft, ClearTop, DXBack, Rect( ClearLeft, ClearTop, ClearRight, ClearBottom ), DDBLTFAST_WAIT ); //clean up before we plot test
              if UseSmallFont then
                pText.PlotTinyTextBlock( GetSlotText, ClearLeft, ClearRight, SmlMsg, Alpha )
              else
                pText.PlotText( GetSlotText, ClearLeft, LrgMsg, Alpha );
            end; //endif button
          end;
          i := i + 1;
        end; //wend
      end; //endif DlgScroll
    end
    else
    begin //drop the piece if we can
    //cleanup
      lpDDSBack.BltFast( Tx, Ty, DXDirty, Rect( 0, 0, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), DDBLTFAST_WAIT );
    //try to drop on ground
      DontAllowDrop := false;
      if pTempItems( ItemList.Items[ CurrentSelectedItem ] ).DXSurfaceIcon = nil then
      begin
        DontAllowDrop := true; //its a quest piece -cannot drop
      end;
      if ( DontAllowDrop = false ) and intersectRect( rRect, rect( 287, 376, 363, 406 ), rect( Tx, Ty, Tx + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, Ty + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ) ) then
      begin
        if GroundOrderList.Count > 0 then
        begin //If we have any ground items
          pTempItems( GroundOrderList.Items[ TopGroundIndex ] ).InvX := 999; //put old item offscreen- no longer on top
          pTempItems( GroundOrderList.Items[ TopGroundIndex ] ).InvY := 999;
          GroundOrderList.Insert( TopGroundIndex, pTempItems( ItemList.Items[ CurrentSelectedItem ] ) );
        end
        else
        begin //there are no items in this list - this will automatically become zero (top spot)
          GroundOrderList.Add( pTempItems( ItemList.Items[ CurrentSelectedItem ] ) );
          TopGroundIndex := 0;
        end;

        lpDDSBack.BltFast( 287, 376, DXBack, Rect( 287, 376, 363, 406 ), DDBLTFAST_WAIT ); //clean out the Ground box
        pTempItems( ItemList.Items[ CurrentSelectedItem ] ).InvX := 288; //325-pTempItems(ItemList.Items[CurrentSelectedItem]).IW div 2;
        pTempItems( ItemList.Items[ CurrentSelectedItem ] ).InvY := 377; //391-pTempItems(ItemList.Items[CurrentSelectedItem]).IH div 2;
        pTempItems( ItemList.Items[ CurrentSelectedItem ] ).WhoHasThis := 3; //ground
        lpDDSBack.BltFast( pTempItems( ItemList.Items[ CurrentSelectedItem ] ).InvX, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).InvY,
          pTempItems( ItemList.Items[ CurrentSelectedItem ] ).DXSurfaceIcon, Rect( 0, 0, GroundListWidth, GroundListHeight ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
        lpDDSBack.BltFast( ClearLeft, ClearTop, DXBack, Rect( ClearLeft, ClearTop, ClearRight, ClearBottom ), DDBLTFAST_WAIT ); //clear text
        CurrentSelectedItem := -1;
        ContainCursor( 0 );
      end
      else if X < 290 then
      begin
      //check left inventory side
        B1 := true; //((X - (pTempItems(ItemList.Items[CurrentSelectedItem]).W div 2) > 2) and (Y - (pTempItems(ItemList.Items[CurrentSelectedItem]).H div 2) > 20)); //is it on the grid?
        B2 := true; //(X < (243 - (pTempItems(ItemList.Items[CurrentSelectedItem]).W div 2 - 9))); //is it on the right side of the grid within 1 block?
        if not B2 then
        begin
          X := X - 18; //we redo this- added a forgivness factor for dropping on right edge, we need to move this back a slot
          B2 := ( X < ( 243 - ( pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W div 2 - 9 ) ) );
        end;
        B3 := true; //(Y < (406 - (pTempItems(ItemList.Items[CurrentSelectedItem]).H div 2 - 9))); //bottom side within 1 block
        if not B3 then
        begin
          Y := Y - 15; //we redo this- added a forgivness factor for dropping on right edge, we need to move this up a slot
          B3 := ( Y < ( 406 - ( pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H div 2 ) ) );
        end;
        B5 := ( pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H < ( 406 - 40 ) );
        B4 := DropAnItem( X, Y ); //CollisionCheck(X, Y);       //does it collide with any other items already in inventory?
        if ( B1 and B2 and B3 and B4 and B5 ) then
        begin //plot the item on the grid if it fits
          //Tx := Integer((X - 18 - (pTempItems(ItemList.Items[CurrentSelectedItem]).W div 2)) div 18) * 18 + 27;
          //Ty := Integer((Y - 32 - (pTempItems(ItemList.Items[CurrentSelectedItem]).H div 2)) div 26) * 26 + 42;
          DrawSub( lpDDSBack, rect( Tx, Ty, Tx + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, Ty + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), Rect( 0, 0, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), pTempItems( ItemList.Items[ CurrentSelectedItem ] ).DXShadow, True, ShadowAlpha );
          lpDDSBack.BltFast( Tx, Ty, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).DXSurface, Rect( 0, 0, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
          pTempItems( ItemList.Items[ CurrentSelectedItem ] ).InvX := Tx;
          pTempItems( ItemList.Items[ CurrentSelectedItem ] ).InvY := Ty;
          pTempItems( ItemList.Items[ CurrentSelectedItem ] ).WhoHasThis := 1; //left character
          pTempItems( ItemList.Items[ CurrentSelectedItem ] ).CharacterHadThisOnHim := true;
          CurrentSelectedItem := -1;
          ContainCursor( 0 );
          lpDDSBack.BltFast( ClearLeft, ClearTop, DXBack, Rect( ClearLeft, ClearTop, ClearRight, ClearBottom ), DDBLTFAST_WAIT ); //erase any message on the screen
        end
        else
        begin //plot failure message
           //clean up - this plots the objects dirty, then the new text, then saves the dirty - prevents Dirty errors
          lpDDSBack.BltFast( Tx, Ty, DXDirty, Rect( 0, 0, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), DDBLTFAST_WAIT );
          lpDDSBack.BltFast( ClearLeft, ClearTop, DXBack, Rect( ClearLeft, ClearTop, ClearRight, ClearBottom ), DDBLTFAST_WAIT ); //clean up before we plot text
          if UseSmallFont then
            pText.PlotTinyTextBlock( txtMessage[ 0 ], ClearLeft, ClearRight, SmlMsg, Alpha )
          else
            pText.PlotText( txtMessage[ 0 ], ClearLeft, LrgMsg, Alpha );
          //save the background to the dirty DD surface based on the floating item
          DXDirty.BltFast( 0, 0, lpDDSBack, Rect( Tx, Ty, Tx + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, Ty + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), DDBLTFAST_WAIT );
        end;
      end
      else
      begin //check right side
      //check left inventory side
        B1 := true; //((X - (pTempItems(ItemList.Items[CurrentSelectedItem]).W div 2) > (GridRightMinX-25)) and (Y - (pTempItems(ItemList.Items[CurrentSelectedItem]).H div 2) > (GridRightMinY-25))); //is it on the grid?
        B2 := true; //(X < (GridRightMaxX - (pTempItems(ItemList.Items[CurrentSelectedItem]).W div 2 - 9))); //is it on the right side of the grid within 1 block?
        if not B2 then
        begin
          X := X - 18; //we redo this- added a forgivness factor for dropping on right edge, we need to move this back a slot
          B2 := ( X < ( GridRightMaxX - ( pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W div 2 - 9 ) ) );
        end;
        B3 := true; //(Y < (GridRightMaxY - (pTempItems(ItemList.Items[CurrentSelectedItem]).H div 2 - 9))); //bottom side within 1 block
        if not B3 then
        begin
          Y := Y - 15; //we redo this- added a forgivness factor for dropping on right edge, we need to move this back a slot
          B3 := ( Y < ( GridRightMaxY - ( pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H div 2 ) ) );
        end;
      //Does the item fit in the right ob box?
        B5 := ( pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H < ( GridRightMaxY - GridRightMinY ) ) and ( pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W < ( GridRightMaxX - GridRightMinX ) );
        B4 := DropAnItem( X, Y ); //CollisionCheck(X, Y);       //does it collide with any other items already in inventory?
        B6 := ( pTempItems( ItemList.Items[ CurrentSelectedItem ] ).DXSurfaceIcon <> nil ); //not a quest item
        if ( B1 and B2 and B3 and B4 and B5 and B6 ) then
        begin //plot the item on the grid if it fits
          //Tx := Integer((X - (GridRightMinX-9) - (pTempItems(ItemList.Items[CurrentSelectedItem]).W div 2)) div 18) * 18 + GridRightMinX;
          //Ty := Integer((Y - (GridRightMinY-9) - (pTempItems(ItemList.Items[CurrentSelectedItem]).H div 2)) div 26) * 26 + GridRightMinY;
          DrawSub( lpDDSBack, rect( Tx, Ty, Tx + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, Ty + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), Rect( 0, 0, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), pTempItems( ItemList.Items[ CurrentSelectedItem ] ).DXShadow, True, ShadowAlpha );
          lpDDSBack.BltFast( Tx, Ty, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).DXSurface, Rect( 0, 0, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
          pTempItems( ItemList.Items[ CurrentSelectedItem ] ).InvX := Tx;
          pTempItems( ItemList.Items[ CurrentSelectedItem ] ).InvY := Ty;
          pTempItems( ItemList.Items[ CurrentSelectedItem ] ).WhoHasThis := 2; //right character or box
          CurrentSelectedItem := -1;
          ContainCursor( 0 );
          lpDDSBack.BltFast( ClearLeft, ClearTop, DXBack, Rect( ClearLeft, ClearTop, ClearRight, ClearBottom ), DDBLTFAST_WAIT ); //erase any message on the screen
        end
        else
        begin //plot failure message
           //clean up - this plots the objects dirty, then the new text, then saves the dirty - prevents Dirty errors
          lpDDSBack.BltFast( Tx, Ty, DXDirty, Rect( 0, 0, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), DDBLTFAST_WAIT );
          lpDDSBack.BltFast( ClearLeft, ClearTop, DXBack, Rect( ClearLeft, ClearTop, ClearRight, ClearBottom ), DDBLTFAST_WAIT ); //clean up before we plot text
          if UseSmallFont then
          begin
            if B5 = false then
              pText.PlotTinyTextBlock( txtMessage[ 1 ], ClearLeft, ClearRight, SmlMsg, Alpha )
            else if B6 = false then //cant drop quest item on other
              pText.PlotTinyTextBlock( txtMessage[ 2 ], ClearLeft, ClearRight, SmlMsg, Alpha )
            else
              pText.PlotTinyTextBlock( txtMessage[ 0 ], ClearLeft, ClearRight, SmlMsg, Alpha );
          end
          else
          begin
            if B5 = false then
              pText.PlotText( txtMessage[ 1 ], ClearLeft, LrgMsg, Alpha )
            else if B6 = false then //cant drop quest item on other
              pText.PlotText( txtMessage[ 2 ], ClearLeft, LrgMsg, Alpha )
            else
              pText.PlotText( txtMessage[ 0 ], ClearLeft, LrgMsg, Alpha );
          end;
          //save the background to the dirty DD surface based on the floating item
          DXDirty.BltFast( 0, 0, lpDDSBack, Rect( Tx, Ty, Tx + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, Ty + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), DDBLTFAST_WAIT );
        end;
      end;
    end; //endif
    lpDDSFront.Flip( nil, DDFLIP_WAIT );
    lpDDSBack.BltFast( 0, 0, lpDDSFront, Rect( 0, 0, 800, 600 ), DDBLTFAST_WAIT );
    MouseCursor.PlotDirty := false;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //TObjInventory.MouseDown

procedure TObjInventory.MouseMove( Sender : TAniview; Shift : TShiftState; X,
  Y, GridX, GridY : integer );
var
  Tw, Th : Integer;
  i : Integer;
const
  FailName : string = 'TObjInventory.MouseMove';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  try
                                   //This assigned(DXBack) is here to keep the program from crashing while Im developing it
    if ( CurrentSelectedItem > -1 ) and Assigned( DXBack ) then
    begin //are we dragging an item?
    //clean up
      lpDDSBack.BltFast( Tx, Ty, DXDirty, Rect( 0, 0, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), DDBLTFAST_WAIT );
    //Compute the coords for the floating item
      Tx := ( X ) - pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W div 2;
      Ty := ( Y ) - pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H div 2;
      if Tx < 0 then
        Tx := 0;
      if Ty < 0 then
        Ty := 0;
      Tw := pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W;
      if ( Tx + Tw ) > 659 then
        Tx := 659 - Tw;

      Th := pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H;
      if ( Ty + Th ) > 463 then
        Ty := 463 - Th;

    //save the background to the dirty DD surface based on the floating item
      DXDirty.BltFast( 0, 0, lpDDSBack, Rect( Tx, Ty, Tx + Tw, Ty + Th ), DDBLTFAST_WAIT );
    //plot the item centered under the mouse pointer
      DrawSub( lpDDSBack, rect( Tx, Ty, Tx + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, Ty + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), Rect( 0, 0, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), pTempItems( ItemList.Items[ CurrentSelectedItem ] ).DXShadow, True, ShadowAlpha );
      lpDDSBack.BltFast( Tx, Ty, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).DXSurface, Rect( 0, 0, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W, pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
      lpDDSFront.Flip( nil, DDFLIP_WAIT );
      lpDDSBack.BltFast( 0, 0, lpDDSFront, Rect( 0, 0, 800, 600 ), DDBLTFAST_WAIT );
      MouseCursor.PlotDirty := false;
    end
    else if Assigned( DXBack ) and ( DlgScroll.ScrollIsShowing = False ) then
    begin //do the rollover
      i := 0; //find the item the mouse is down over
      lpDDSBack.BltFast( ClearLeft, ClearTop, DXBack, Rect( ClearLeft, ClearTop, ClearRight, ClearBottom ), DDBLTFAST_WAIT ); //clean up before we plot text
      while ( i < ItemList.Count ) and ( CurrentSelectedItem = -1 ) do
      begin
        if ( ( x ) >= pTempItems( ItemList.Items[ i ] ).InvX ) and ( ( x ) <= ( pTempItems( ItemList.Items[ i ] ).InvX + pTempItems( ItemList.Items[ i ] ).W ) ) and ( ( Y ) >= pTempItems( ItemList.Items[ i ] ).InvY ) and ( ( Y ) <= pTempItems( ItemList.Items[ i ] ).InvY + pTempItems( ItemList.Items[ i ] ).H ) then
        begin
          CurrentSelectedItem := i; //assign it for the sake of PlotText
//        if UseSmallFont then
          pText.PlotTinyTextBlock( ( GetSlotText + txtMessage[ 3 ] ), ClearLeft, ClearRight, SmlMsg, Alpha );
//        else
//          pText.PlotText((GetSlotText + txtMessage[3]), ClearLeft, LrgMsg,Alpha);
        //i:=999;
        end;
        i := i + 1;
      end; //wend
    //If we arent over an item see if we're over the ground slot
      if ( x > 287 ) and ( x < 363 ) and ( y > 363 ) and ( y < 406 ) and ( CurrentSelectedItem = -1 ) then
      begin //over the ground slot
        if GroundOrderList.Count > 0 then
        begin
          CurrentSelectedItem := ItemList.IndexOf( GroundOrderList.items[ TopGroundIndex ] );
//          if UseSmallFont then
          pText.PlotTinyTextBlock( ( GetSlotText + txtMessage[ 3 ] ), ClearLeft, ClearRight, SmlMsg, Alpha );
//          else
//            pText.PlotText((GetSlotText + txtMessage[3]), ClearLeft, LrgMsg,Alpha);
        end;
      end; //endif
    //Clean up arrows and back to game
      lpDDSBack.BltFast( 300, 194, DXBack, Rect( 300, 194, 348, 250 ), DDBLTFAST_WAIT );
      lpDDSBack.BltFast( 271, 385, DXBack, Rect( 271, 385, 271 + 15, 385 + 20 ), DDBLTFAST_WAIT );
      lpDDSBack.BltFast( 364, 385, DXBack, Rect( 364, 385, 364 + 12, 385 + 20 ), DDBLTFAST_WAIT );
      lpDDSBack.BltFast( 588, 407, DXBack, Rect( 588, 407, 588 + 77, 407 + 54 ), DDBLTFAST_WAIT );
      if CurrentSelectedItem = -1 then
      begin //If we arent over an item then check arrows and back button
        if PtinRect( rect( 271, 375, 287, 407 ), point( X, Y ) ) then
        begin //over left arrow
          //plot highlighted arrow
          lpDDSBack.BltFast( 272, 385, DXLeftArrow, Rect( 0, 0, 14, 15 ), DDBLTFAST_WAIT );
          //plot a bit of informative text
          lpDDSBack.BltFast( ClearLeft, ClearTop, DXBack, Rect( ClearLeft, ClearTop, ClearRight, ClearBottom ), DDBLTFAST_WAIT ); //clean up before we plot text
          if UseSmallFont then
            pText.PlotTinyTextBlock( ( txtMessage[ 4 ] ), ClearLeft, ClearRight, SmlMsg, Alpha )
          else
            pText.PlotText( ( txtMessage[ 4 ] ), ClearLeft, LrgMsg, Alpha );
        end
        else if PtinRect( rect( 364, 375, 376, 407 ), point( X, Y ) ) then
        begin //over right arrow
          //plot highlighted arrow
          lpDDSBack.BltFast( 365, 387, DXRightArrow, Rect( 0, 0, 11, 11 ), DDBLTFAST_WAIT );
          //plot a bit of informative text
          lpDDSBack.BltFast( ClearLeft, ClearTop, DXBack, Rect( ClearLeft, ClearTop, ClearRight, ClearBottom ), DDBLTFAST_WAIT ); //clean up before we plot text
          if UseSmallFont then
            pText.PlotTinyTextBlock( ( txtMessage[ 5 ] ), ClearLeft, ClearRight, SmlMsg, Alpha )
          else
            pText.PlotText( ( txtMessage[ 5 ] ), ClearLeft, LrgMsg, Alpha );
        end
        else if PtinRect( rect( 588, 407, 588 + 77, 412 + 54 ), point( X, Y ) ) then
        begin //over back button
          //plot highlighted back to game
          lpDDSBack.BltFast( 588, 407, DXBackToGame, Rect( 0, 0, 77, 54 ), DDBLTFAST_WAIT );
          //don't plot a bit of informative text, just clean up
          lpDDSBack.BltFast( ClearLeft, ClearTop, DXBack, Rect( ClearLeft, ClearTop, ClearRight, ClearBottom ), DDBLTFAST_WAIT ); //clean up before we plot text
        end
        else if PtinRect( rect( 300, 194, 347, 218 ), point( X, Y ) ) then
        begin //over right ALL arrow
          //plot highlighted arrow
          lpDDSBack.BltFast( 300, 194, DXRightAll, Rect( 0, 0, 47, 22 ), DDBLTFAST_WAIT );
          //plot a bit of informative text
          lpDDSBack.BltFast( ClearLeft, ClearTop, DXBack, Rect( ClearLeft, ClearTop, ClearRight, ClearBottom ), DDBLTFAST_WAIT ); //clean up before we plot text
          if UseSmallFont then
          begin
            if OtherOb is TCharacter then
              pText.PlotTinyTextBlock( ( txtMessage[ 6 ] + Character.name + txtMessage[ 7 ] + TCharacter( OtherOb ).name + '.' ), ClearLeft, ClearRight, SmlMsg, Alpha )
            else
              pText.PlotTinyTextBlock( ( txtMessage[ 6 ] + Character.name + txtMessage[ 7 ] + TContainer( OtherOb ).name + '.' ), ClearLeft, ClearRight, SmlMsg, Alpha );
          end
          else
          begin
            if OtherOb is TCharacter then
              pText.PlotText( ( txtMessage[ 6 ] + Character.name + txtMessage[ 7 ] + TCharacter( OtherOb ).name + '.' ), ClearLeft, LrgMsg, Alpha )
            else
              pText.PlotText( ( txtMessage[ 6 ] + Character.name + txtMessage[ 7 ] + TContainer( OtherOb ).name + '.' ), ClearLeft, LrgMsg, Alpha );
          end;
        end
        else if PtinRect( rect( 300, 225, 347, 247 ), point( X, Y ) ) then
        begin //over left ALL arrow
          //plot highlighted arrow
          lpDDSBack.BltFast( 300, 225, DXLeftAll, Rect( 0, 0, 47, 22 ), DDBLTFAST_WAIT );
          //plot a bit of informative text
          lpDDSBack.BltFast( ClearLeft, ClearTop, DXBack, Rect( ClearLeft, ClearTop, ClearRight, ClearBottom ), DDBLTFAST_WAIT ); //clean up before we plot text
          if UseSmallFont then
          begin
            if OtherOb is TCharacter then
              pText.PlotTinyTextBlock( ( txtMessage[ 6 ] + Character.name + txtMessage[ 7 ] + TCharacter( OtherOb ).name + '.' ), ClearLeft, ClearRight, SmlMsg, Alpha )
            else
              pText.PlotTinyTextBlock( ( txtMessage[ 6 ] + Character.name + txtMessage[ 7 ] + TContainer( OtherOb ).name + '.' ), ClearLeft, ClearRight, SmlMsg, Alpha );
          end
          else
          begin
            if OtherOb is TCharacter then
              pText.PlotText( ( txtMessage[ 6 ] + TCharacter( OtherOb ).name + txtMessage[ 7 ] + Character.name + '.' ), ClearLeft, LrgMsg, Alpha )
            else
              pText.PlotText( ( txtMessage[ 6 ] + TContainer( OtherOb ).name + txtMessage[ 7 ] + Character.name + '.' ), ClearLeft, LrgMsg, Alpha )
          end;
        end
      end; //endif CurrentSelectedItem

      CurrentSelectedItem := -1; //deassign it
      lpDDSFront.Flip( nil, DDFLIP_WAIT );
      lpDDSBack.BltFast( 0, 0, lpDDSFront, Rect( 0, 0, 800, 600 ), DDBLTFAST_WAIT );
      MouseCursor.PlotDirty := false;
    end;

  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //TObjInventory.MouseMove

procedure TObjInventory.MouseUp( Sender : TAniview; Button : TMouseButton;
  Shift : TShiftState; X, Y, GridX, GridY : integer );
const
  FailName : string = 'TObjInventory.MouseUp';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  try

    DlgScroll.KeepOnScrolling := false;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end;

procedure TObjInventory.Paint;
var
  i : Integer;
const
  FailName : string = 'TObjInventory.Paint';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  try

    lpDDSBack.BltFast( 0, 0, DXBack, Rect( 0, 0, 679, 476 ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
  //Now plot all of the items on the grid(s), and ground slots
    for i := 0 to ItemList.Count - 1 do
    begin
      if pTempItems( ItemList.Items[ i ] ).WhoHasThis = 3 then //if in ground slot plot icon
        lpDDSBack.BltFast( pTempItems( ItemList.Items[ i ] ).InvX, pTempItems( ItemList.Items[ i ] ).InvY, pTempItems( ItemList.Items[ i ] ).DXSurfaceIcon, Rect( 0, 0, GroundListWidth, GroundListHeight ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT )
      else
      begin
        DrawSub( lpDDSBack, rect( pTempItems( ItemList.Items[ i ] ).InvX, pTempItems( ItemList.Items[ i ] ).InvY, pTempItems( ItemList.Items[ i ] ).InvX + pTempItems( ItemList.Items[ i ] ).W, pTempItems( ItemList.Items[ i ] ).InvY + pTempItems( ItemList.Items[ i ] ).H ), Rect( 0, 0, pTempItems( ItemList.Items[ i ] ).W, pTempItems( ItemList.Items[ i ] ).H ), pTempItems( ItemList.Items[ i ] ).DXShadow, True, ShadowAlpha );
        lpDDSBack.BltFast( pTempItems( ItemList.Items[ i ] ).InvX, pTempItems( ItemList.Items[ i ] ).InvY, pTempItems( ItemList.Items[ i ] ).DXSurface, Rect( 0, 0, pTempItems( ItemList.Items[ i ] ).W, pTempItems( ItemList.Items[ i ] ).H ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT )
      end;
    end;

  //Now put the names up
    pText.PlotTextCentered( Character.name, 27, 243, 10, Alpha );
    if OtherOb is TCharacter then
      pText.PlotTextCentered( TCharacter( OtherOb ).name, 417, 633, 10, Alpha )
    else
      pText.PlotTextCentered( TContainer( OtherOb ).name, 417, 633, 10, Alpha );

    lpDDSFront.Flip( nil, DDFLIP_WAIT );
    lpDDSBack.BltFast( 0, 0, lpDDSFront, Rect( 0, 0, 800, 600 ), DDBLTFAST_WAIT );
    MouseCursor.PlotDirty := false;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //TObjInventory.Paint;

function TObjInventory.CollisionCheck( X, Y : Integer ) : Boolean;
var
  i : Integer;
  R1, R2, R3 : TRect; //R1 is the rect desribing the dragged item's destination R2 is a given inventory item rect, r3 is the result rect if collison (unused)
  k : Boolean;
  CollisionHasNotOccured : Boolean;

const
  FailName : string = 'TObjInventory.CollisionCheck';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  result := false;
  try

    CollisionHasNotOccured := True;
  //first get the rectangle desribing the area where this item will land on the grid
    if X < 290 then
    begin
      R1.Left := Integer( ( X - 18 - ( pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W div 2 ) ) div 18 ) * 18 + 27;
      R1.Top := Integer( ( Y - 32 - ( pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H div 2 ) ) div 26 ) * 26 + 42;
    end
    else
    begin
      R1.Left := Integer( ( X - ( GridRightMinX - 9 ) - ( pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W div 2 ) ) div 18 ) * 18 + GridRightMinX;
      R1.Top := Integer( ( Y - ( GridRightMinY - 9 ) - ( pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H div 2 ) ) div 26 ) * 26 + GridRightMinY;
    end;
    R1.Right := R1.Left + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W;
    R1.Bottom := R1.Top + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H;

    for i := 0 to ItemList.Count - 1 do
    begin //check where we will land vs all other inv items for collision
      if i <> CurrentSelectedItem then
      begin //if this isnt the dragged item check for collision
        R2.Left := pTempItems( ItemList.Items[ i ] ).InvX; //stuff this inventory item into a rect
        R2.Right := R2.Left + pTempItems( ItemList.Items[ i ] ).W;
        R2.Top := pTempItems( ItemList.Items[ i ] ).InvY;
        R2.Bottom := R2.Top + pTempItems( ItemList.Items[ i ] ).H;
        k := IntersectRect( R3, R2, R1 );
        if k = True then
          CollisionHasNotOccured := False; //we hit something
      end; //endif
    end; //end for
    Result := CollisionHasNotOccured;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //TObjInventory.CollisionCheck


procedure TObjInventory.MoveAll( Source, Destination : integer );
var
  i, j, k : integer;
  gWidth : integer;
  gHeight : integer;

const
  FailName : string = 'TObjInventory.MoveAll';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  try

    if ( OtherOb is TCharacter ) or ( Destination = 1 ) then
    begin //if going to player1, or secondob is a player
      gWidth := 6 * 2; //each grid is 2x2
      gHeight := 7 * 2;
    end
    else
    begin
      gWidth := TContainer( OtherOb ).GridWidth * 2;
      gHeight := TContainer( OtherOb ).GridHeight * 2;
    end; //endif

    for i := 0 to ItemList.count - 1 do
    begin
      if pTempItems( ItemList.Items[ i ] ).WhoHasThis = Source then
      begin //if source has this item
        j := 0;
        while j <= ( gWidth - pTempItems( ItemList.Items[ i ] ).pItem.InvW ) do
        begin //try to squeeze it in start upper left going to lower right
          k := 0;
          while k <= ( gHeight - pTempItems( ItemList.Items[ i ] ).pItem.InvH ) do
          begin
            CurrentSelectedItem := i;
            if Source = 1 then
            begin //if going from left player to player ob
              if pTempItems( ItemList.Items[ i ] ).DXSurfaceIcon <> nil then
              begin //dont move quest items
                if CollisionCheck( ( j * 18 ) + GridRightMinX + pTempItems( ItemList.Items[ i ] ).W div 2, ( k * 26 ) + GridRightMinY + pTempItems( ItemList.Items[ i ] ).H div 2 ) then
                begin //if it fits, stick it in there
                  pTempItems( ItemList.Items[ i ] ).InvX := j * 18 + GridRightMinX;
                  pTempItems( ItemList.Items[ i ] ).InvY := k * 26 + GridRightMinY;
                  pTempItems( ItemList.Items[ i ] ).WhoHasThis := Destination; //destination character/container
                  k := 99;
                  j := 99; //kick out- we've placed it
                end;
              end;
            end //going form left chat/container to player
            else
            begin
              if CollisionCheck( ( j * 18 ) + 27 + pTempItems( ItemList.Items[ i ] ).W div 2, ( k * 26 ) + 42 + pTempItems( ItemList.Items[ i ] ).H div 2 ) then
              begin //if it fits, stick it in there
                pTempItems( ItemList.Items[ i ] ).InvX := j * 18 + 27;
                pTempItems( ItemList.Items[ i ] ).InvY := k * 26 + 42;
                pTempItems( ItemList.Items[ i ] ).WhoHasThis := Destination; //destination character/container
                pTempItems( ItemList.Items[ i ] ).CharacterHadThisOnHim := true;
                k := 99;
                j := 99; //kick out- we've placed it
              end;
            end;
            k := k + 1;
          end; //wend
          j := j + 1;
        end; //wend
      end; //endif
    end; //end for

    CurrentSelectedItem := -1; //clear it
    paint; //refresh the screen
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //TObjInventory.MoveAll



function TObjInventory.GetSlotText : string;
var
  Sentence : string;
const
  FailName : string = 'TObjInventory.GetSlotText';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  result := 'failed';
  try

    Sentence := pTempItems( ItemList.Items[ CurrentSelectedItem ] ).PItem.Name;
    Result := ( Sentence );
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //TObjInventory.GetSlotText



procedure TObjInventory.WriteTheInventoryData;
var
  i : Integer;
const
  FailName : string = 'TObjInventory.WriteTheInventoryData';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  try

  //Clear the Characters/Container Inventory
    Character.Inventory.Clear;
    if OtherOb is TCharacter then
      TCharacter( OtherOb ).Inventory.Clear
    else
      TContainer( OtherOb ).Inventory.Clear;
  //Assign the new values
    for i := 0 to ItemList.Count - 1 do
    begin
      if pTempItems( ItemList.Items[ i ] ).WhoHasThis = 1 then
      begin
        pTempItems( ItemList.Items[ i ] ).PItem.InvX := ( pTempItems( ItemList.Items[ i ] ).InvX - 27 ) div 18;
        pTempItems( ItemList.Items[ i ] ).PItem.InvY := ( pTempItems( ItemList.Items[ i ] ).InvY - 42 ) div 26;
        pTempItems( ItemList.Items[ i ] ).PItem.Enabled := False; //this is only true if an item in on the ground
        Character.Inventory.Add( pTempItems( ItemList.Items[ i ] ).PItem );
       //Make sure part has correct resource for base type
        pTempItems( ItemList.Items[ i ] ).PItem.LayeredImage := PartManager.GetImageFile( pTempItems( ItemList.Items[ i ] ).PItem.PartName, TCharacterResource( Character.Resource ).NakedName );
        pTempItems( ItemList.Items[ i ] ).PItem.Resource := PartManager.GetLayerResource( pTempItems( ItemList.Items[ i ] ).PItem.LayeredImage );
      end
      else if pTempItems( ItemList.Items[ i ] ).WhoHasThis = 2 then
      begin
        pTempItems( ItemList.Items[ i ] ).PItem.InvX := ( pTempItems( ItemList.Items[ i ] ).InvX - GridRightMinX ) div 18;
        pTempItems( ItemList.Items[ i ] ).PItem.InvY := ( pTempItems( ItemList.Items[ i ] ).InvY - GridRightMinY ) div 26;
        pTempItems( ItemList.Items[ i ] ).PItem.Enabled := False; //this is only true if an item in on the ground
        if OtherOb is TCharacter then
        begin
          TCharacter( OtherOb ).Inventory.Add( pTempItems( ItemList.Items[ i ] ).PItem );
          //Make sure part has correct resource for base type
          pTempItems( ItemList.Items[ i ] ).PItem.LayeredImage := PartManager.GetImageFile( pTempItems( ItemList.Items[ i ] ).PItem.PartName, TCharacterResource( TCharacter( OtherOb ).Resource ).NakedName );
          pTempItems( ItemList.Items[ i ] ).PItem.Resource := PartManager.GetLayerResource( pTempItems( ItemList.Items[ i ] ).PItem.LayeredImage );
        end
        else
          TContainer( OtherOb ).Inventory.Add( pTempItems( ItemList.Items[ i ] ).PItem );
      end
      else
      begin //its on the ground- WhoHasThis=3
      //put the item at the characters pos on the ground
        pTempItems( ItemList.Items[ i ] ).PItem.SetPos( Character.X, Character.Y, 0 );
        pTempItems( ItemList.Items[ i ] ).PItem.Enabled := True; //make it visible
        if pTempItems( ItemList.Items[ i ] ).CharacterHadThisOnHim and CheckForGroundDrop then
          pTempItems( ItemList.Items[ i ] ).PItem.Drop;

      end; //endif
    end; //endfor
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //TObjInventory.WriteTheInventoryData



procedure TObjInventory.ContainCursor( action : integer );
var
  prRect : PRect;
const
  FailName : string = 'TObjInventory.ContainCursor';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  try

    new( prRect );
    prRect.top := 0;
    prRect.left := 0;
    if Action = 1 then
    begin //restore to fullscreen
      prRect.bottom := 478;
      prRect.Right := 640;
    end
    else
    begin //constrict to main inventory area
      prRect.bottom := 600;
      prRect.Right := 800;
      paint;
    end;
    ClipCursor( prRect );
    Dispose( prRect );
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //TObjInventory.ContainCursor


procedure TObjInventory.BuildGrid;
var
  i, j : integer;
  StartX, StartY : integer;
  DXGrid : IDirectDrawSurface; //DD surface holding our chunk O' grid to draw right grid with
  BM : TBitmap;
const
  FailName : string = 'TObjInventory.BuildGrid';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  try

  //Load the grid graphic, and draw the left inventory area before we blit the screen to the backbuffer
    BM := TBitmap.create;
    BM.LoadFromFile( InterfacePath + 'obInvGrid.bmp' );
    DXGrid := DDGetImage( lpDD, BM, $00FFFF00, False );
    BM.free;

    if OtherOb is TCharacter then
    begin
      for j := 0 to 6 do
      begin
        for i := 0 to 5 do
        begin
          DXBack.BltFast( 597 - i * 36, 353 - j * 52, DXGrid, rect( 0, 0, 38, 54 ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
        end;
      end;
     //Player Grid on right
      GridRightMinX := 417;
      GridRightMaxX := 597 + 36;
      GridRightMinY := 42;
      GridRightMaxY := 353 + 53;
    end
    else
    begin //it's a container
      StartX := 525 + ( ( TContainer( OtherOb ).GridWidth * 36 ) div 2 ) - 36;
      StartY := 222 + ( ( TContainer( OtherOb ).GridHeight * 52 ) div 2 ) - 52;
      for j := 0 to TContainer( OtherOb ).GridHeight - 1 do
      begin
        for i := 0 to TContainer( OtherOb ).GridWidth - 1 do
        begin
          DXBack.BltFast( StartX - i * 36, StartY - j * 52, DXGrid, rect( 0, 0, 38, 54 ), DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
        end;
      end;
     //Object Grid on right
      GridRightMinX := 525 - ( ( TContainer( OtherOb ).GridWidth * 36 ) div 2 );
      GridRightMaxX := 525 + ( ( TContainer( OtherOb ).GridWidth * 36 ) div 2 );
      GridRightMinY := 222 - ( ( TContainer( OtherOb ).GridHeight * 52 ) div 2 );
      GridRightMaxY := 222 + ( ( TContainer( OtherOb ).GridHeight * 52 ) div 2 );
    end; //endif
    DXGrid := nil; //dont need it anymore
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //TObjInventory.BuildGrid;


procedure TObjInventory.ShowOpenInventorySlots;
var
  i, j, k, m, n : integer;
  gWidth : integer;
  gHeight : integer;
  XX, YY : integer;

const
  FailName : string = 'TObjInventory.ShowOpenInventroySlots';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  try

    gWidth := 6 * 2; //each grid is 2x2
    gHeight := 7 * 2;
   //Clear the Array
    for i := 0 to 11 do
    begin
      for j := 0 to 13 do
      begin
        PlotArray[ i, j ] := 0;
      end;
    end;

    j := 0;
    i := CurrentSelectedItem;
    while j <= ( gWidth - pTempItems( ItemList.Items[ i ] ).pItem.InvW ) do
    begin //try to squeeze it in start upper left going to lower right
      k := 0;
      while k <= ( gHeight - pTempItems( ItemList.Items[ i ] ).pItem.InvH ) do
      begin
        XX := ( j * 18 ) + 27 + pTempItems( ItemList.Items[ i ] ).W div 2;
        YY := ( k * 26 ) + 42 + pTempItems( ItemList.Items[ i ] ).H div 2;
        if CollisionCheck( XX, YY ) then
        begin //if it mark the array
          for m := 0 to pTempItems( ItemList.Items[ i ] ).pItem.InvW - 1 do
          begin
            for n := 0 to pTempItems( ItemList.Items[ i ] ).pItem.InvH - 1 do
            begin
              PlotArray[ j + m, k + n ] := 1;
            end; //n
          end; //m
        end;
        k := k + 1;
      end; //wend
      j := j + 1;
    end; //wend
    for i := 0 to 11 do
    begin
      for j := 0 to 13 do
      begin
        if PlotArray[ i, j ] = 0 then
          DrawAlpha( lpDDSBack, rect( i * 18 + 27, j * 26 + 42, i * 18 + 27 + 18, j * 26 + 42 + 26 ), rect( 0, 0, 25, 25 ), DXBrown, False, 90 );
      end;
    end;
// Now for the right area
    if ( OtherOb is TCharacter ) then
    begin //if going to player1, or secondob is a player
      gWidth := 6 * 2; //each grid is 2x2
      gHeight := 7 * 2;
    end
    else
    begin
      gWidth := TContainer( OtherOb ).GridWidth * 2;
      gHeight := TContainer( OtherOb ).GridHeight * 2;
    end; //endif

   //Clear the Array
    for i := 0 to 20 do
    begin
      for j := 0 to 20 do
      begin
        PlotArray2[ i, j ] := 0;
      end;
    end;
    j := 0;
    i := CurrentSelectedItem;
    while j <= ( gWidth - pTempItems( ItemList.Items[ i ] ).pItem.InvW ) do
    begin //try to squeeze it in start upper left going to lower right
      k := 0;
      while k <= ( gHeight - pTempItems( ItemList.Items[ i ] ).pItem.InvH ) do
      begin
        XX := ( j * 18 ) + GridRightMinX + pTempItems( ItemList.Items[ i ] ).W div 2;
        YY := ( k * 26 ) + GridRightMinY + pTempItems( ItemList.Items[ i ] ).H div 2;
         //  XX:=(j*18)+418+pTempItems(ItemList.Items[i]).W div 2;
         //  YY:=(k*26)+41+pTempItems(ItemList.Items[i]).H div 2;

        if CollisionCheck( XX, YY ) then
        begin //if it mark the array
          for m := 0 to pTempItems( ItemList.Items[ i ] ).pItem.InvW - 1 do
          begin
            for n := 0 to pTempItems( ItemList.Items[ i ] ).pItem.InvH - 1 do
            begin
              PlotArray2[ j + m, k + n ] := 1;
            end; //n
          end; //m
        end;
        k := k + 1;
      end; //wend
      j := j + 1;
    end; //wend
    for i := 0 to gWidth - 1 do
    begin
      for j := 0 to gHeight - 1 do
      begin
        if PlotArray2[ i, j ] = 0 then
          DrawAlpha( lpDDSBack, rect( i * 18 + GridRightMinX, j * 26 + GridRightMinY, i * 18 + GridRightMinX + 18, j * 26 + GridRightMinY + 26 ), rect( 0, 0, 25, 25 ), DXBrown, False, 90 );
      end;
    end;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //TObjInventory.ShowOpenInventorySlots

function TObjInventory.DropAnItem( X, Y : integer ) : boolean;
var
  i, j, TheVal : integer;
  gWidth, gHeight, gLeft, gTop, gRight, gBottom : integer;
  XX, YY : Integer;
  FoundASafePlaceToDrop : boolean;
  LastLowTotal : integer;
const
  FailName : string = 'TObjInventory.DropAnItem';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  Result := false;
  try

    LastLowTotal := 9999; //initialize to insanely high number
    FoundASafePlaceToDrop := false;
   //upper left corner of floating item
    XX := X - pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W div 2;
    YY := Y - pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H div 2;

    if XX < 290 then
    begin //if left grid (player)
      gWidth := 12;
      gHeight := 14;
      gLeft := 27;
      gTop := 42;
      gRight := 243;
      gBottom := 407;
    end
    else
    begin //its the object or char on the right
      if pTempItems( ItemList.Items[ CurrentSelectedItem ] ).DXSurfaceIcon = nil then
      begin
        Result := false;
        exit; //quest item- just skip out
      end;

      if ( OtherOb is TCharacter ) then
      begin
        gWidth := 6 * 2; //each grid is 2x2
        gHeight := 7 * 2;
        gLeft := GridRightMinX;
        gTop := GridRightMinY;
        gRight := GridRightMaxX;
        gBottom := GridRightMaxY;
      end
      else
      begin
        gWidth := TContainer( OtherOb ).GridWidth * 2;
        gHeight := TContainer( OtherOb ).GridHeight * 2;
        gLeft := GridRightMinX;
        gTop := GridRightMinY;
        gRight := GridRightMaxX;
        gBottom := GridRightMaxY;
      end; //endif
    end;

    for i := 0 to gWidth - 1 do
    begin
      for j := 0 to gHeight - 1 do
      begin
        if XX < 290 then
          TheVal := PlotArray[ i, j ]
        else
          TheVal := PlotArray2[ i, j ];
        if TheVal = 1 then
        begin
          if ( ( i * 18 + gLeft + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W ) < gRight + 1 ) and ( ( j * 26 + gTop + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H ) < gBottom + 1 ) and ( CollisionCheck( i * 18 + gLeft + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).W div 2, j * 26 + gTop + pTempItems( ItemList.Items[ CurrentSelectedItem ] ).H div 2 ) ) then
          begin
                //find the available slot closest ot the upper left corner of floating item
            if abs( XX - ( i * 18 + gLeft ) ) + abs( YY - ( j * 26 + gTop ) ) < LastLowTotal then
            begin //closer to upper corner of bitmap
              LastLowTotal := abs( XX - ( i * 18 + gLeft ) ) + abs( YY - ( j * 26 + gTop ) );
              Tx := i * 18 + gLeft;
              Ty := j * 26 + gTop;
              FoundASafePlaceToDrop := true;
            end;
          end; //endif
        end; //endif plotarray
      end; //for j
    end; //for i

    Result := FoundASafePlaceToDrop;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //TObjInventory.DropAnItem

procedure TObjInventory.Release;
var
  i : integer;
const
  FailName : string = 'TObjInventory.Release';
begin
{$IFDEF DODEBUG}
  if ( CurrDbgLvl >= DbgLvlSevere ) then
    Log.LogEntry( FailName );
{$ENDIF}
  try
    ExText.close;
    ContainCursor( 0 );
    CheckForGroundDrop := true;
    WriteTheInventoryData;
    pText.UnloadTinyFontGraphic;
    DXBrown := nil;
    DlgScroll.free;
    DlgScroll := nil;
    DXBack := nil;
    DXRightArrow := nil;
    DXLeftArrow := nil;
    DXBackToGame := nil;
    DXRightAll := nil;
    DXLeftAll := nil;
    DxDirty := nil;
  //ItemList Barbie pic surface cleanup
    for i := 0 to ItemList.Count - 1 do
    begin
      if Assigned( pTempItems( ItemList.Items[ i ] ).DXSurface ) then
        pTempItems( ItemList.Items[ i ] ).DXSurface := nil;
      if Assigned( pTempItems( ItemList.Items[ i ] ).DXSurfaceIcon ) then
        pTempItems( ItemList.Items[ i ] ).DXSurfaceIcon := nil;
      if Assigned( pTempItems( ItemList.Items[ i ] ).DXShadow ) then
        pTempItems( ItemList.Items[ i ] ).DXShadow := nil;

    end;

  //ItemsList Cleanup
    if Assigned( ItemList ) then
    begin
      for i := 0 to ( ItemList.Count - 1 ) do
      begin
        pInventoryItem := pTempItems( ItemList.Items[ i ] );
        Dispose( pInventoryItem );
      end;
      ItemList.Free;
      ItemList := nil;
    end;
    GroundOrderList.Free;
    GroundOrderList := nil;


    inherited;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //TObjInventory.Release


end.
