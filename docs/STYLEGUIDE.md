# Style Guide

## UI Rules (Required)
1) One vertical scroll per screen
   - Use CustomScrollView + Slivers for long screens
   - Do not nest vertical SingleChildScrollView + ListView/GridView
     (except shrinkWrap + NeverScrollable)

2) Responsive grids
   - Use SliverGridDelegateWithMaxCrossAxisExtent
   - Avoid fixed crossAxisCount on primary screens

3) RTL
   - Use EdgeInsetsDirectional/AlignmentDirectional
   - Avoid hardcoded left/right

## Shared Components (Required)
- AppSearchField
- AppImage (CachedNetworkImage + placeholder)
- AppLoading / AppEmptyState
- AppButton / AppCard / AppInput (as needed)

## Design Tokens
- Spacing: 4/8/12/16/24/32
- Radius: 8/12/16
- Typography: title/body/caption (unified via Theme)

## Performance
- Images: CachedNetworkImage only
- Lists: itemExtent/const widgets where possible
