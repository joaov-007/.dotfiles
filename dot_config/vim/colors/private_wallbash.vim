" Name:         wallbash
" Description:  wallbash template
" Author:       The HyDE Project
" License:      Same as Vim
" Last Change:  April 2025

if exists('g:loaded_wallbash') | finish | endif
let g:loaded_wallbash = 1


" Detect background based on terminal colors
if $BACKGROUND =~# 'light'
  set background=light
else
  set background=dark
endif

" hi clear
let g:colors_name = 'wallbash'

let s:t_Co = &t_Co

" Terminal color setup
if (has('termguicolors') && &termguicolors) || has('gui_running')
  let s:is_dark = &background == 'dark'
  
  " Define terminal colors based on the background
  if s:is_dark
    let g:terminal_ansi_colors = ['2A2A3A', 'A38465', '7A7AC2', 'C28D7A', 
                                \ '6C65A3', 'E6AE9A', '9A9AE6', '101010',
                                \ '525062', 'C29D7A', '9A9AE6', 'F0BDAA', 
                                \ '827AC2', 'F0BDAA', 'AAAAF0', 'FFFFFF']
  else
    " Lighter colors for light theme
    let g:terminal_ansi_colors = ['FFFFFF', 'E6BF9A', 'AAAAF0', 'F0BDAA', 
                                \ 'A29AE6', 'FFDACC', 'CCCCFF', 'B19084',
                                \ '101010', 'F0CCAA', 'CCCCFF', 'FFDACC', 
                                \ 'B2AAF0', 'FFDACC', 'CCCCFF', '2A2A3A']
  endif
  
  " Nvim uses g:terminal_color_{0-15} instead
  for i in range(g:terminal_ansi_colors->len())
    let g:terminal_color_{i} = g:terminal_ansi_colors[i]
  endfor
endif

      " For Neovim compatibility
      if has('nvim')
        " Set Neovim specific terminal colors 
        let g:terminal_color_0 = '#' . g:terminal_ansi_colors[0]
        let g:terminal_color_1 = '#' . g:terminal_ansi_colors[1]
        let g:terminal_color_2 = '#' . g:terminal_ansi_colors[2]
        let g:terminal_color_3 = '#' . g:terminal_ansi_colors[3]
        let g:terminal_color_4 = '#' . g:terminal_ansi_colors[4]
        let g:terminal_color_5 = '#' . g:terminal_ansi_colors[5]
        let g:terminal_color_6 = '#' . g:terminal_ansi_colors[6]
        let g:terminal_color_7 = '#' . g:terminal_ansi_colors[7]
        let g:terminal_color_8 = '#' . g:terminal_ansi_colors[8]
        let g:terminal_color_9 = '#' . g:terminal_ansi_colors[9]
        let g:terminal_color_10 = '#' . g:terminal_ansi_colors[10]
        let g:terminal_color_11 = '#' . g:terminal_ansi_colors[11]
        let g:terminal_color_12 = '#' . g:terminal_ansi_colors[12]
        let g:terminal_color_13 = '#' . g:terminal_ansi_colors[13]
        let g:terminal_color_14 = '#' . g:terminal_ansi_colors[14]
        let g:terminal_color_15 = '#' . g:terminal_ansi_colors[15]
      endif

" Function to dynamically invert colors for UI elements
function! s:inverse_color(color)
  " This function takes a hex color (without #) and returns its inverse
  " Convert hex to decimal values
  let r = str2nr(a:color[0:1], 16)
  let g = str2nr(a:color[2:3], 16)
  let b = str2nr(a:color[4:5], 16)
  
  " Calculate inverse (255 - value)
  let r_inv = 255 - r
  let g_inv = 255 - g
  let b_inv = 255 - b
  
  " Convert back to hex
  return printf('%02x%02x%02x', r_inv, g_inv, b_inv)
endfunction

" Function to be called for selection background
function! InverseSelectionBg()
  if &background == 'dark'
    return 'CCCCFF'
  else
    return '2D2952'
  endif
endfunction

" Add high-contrast dynamic selection highlighting using the inverse color function
augroup WallbashDynamicHighlight
  autocmd!
  " Update selection highlight when wallbash colors change
  autocmd ColorScheme wallbash call s:update_dynamic_highlights()
augroup END

function! s:update_dynamic_highlights()
  let l:bg_color = synIDattr(synIDtrans(hlID('Normal')), 'bg#')
  if l:bg_color != ''
    let l:bg_color = l:bg_color[1:] " Remove # from hex color
    let l:inverse = s:inverse_color(l:bg_color)
    
    " Apply inverse color to selection highlights
    execute 'highlight! CursorSelection guifg=' . l:bg_color . ' guibg=#' . l:inverse
    
    " Link dynamic highlights to various selection groups
    highlight! link NeoTreeCursorLine CursorSelection
    highlight! link TelescopeSelection CursorSelection
    highlight! link CmpItemSelected CursorSelection
    highlight! link PmenuSel CursorSelection
    highlight! link WinSeparator VertSplit
  endif
endfunction

" Make selection visible right away for current colorscheme
call s:update_dynamic_highlights()

" Conditional highlighting based on background
if &background == 'dark'
  " Base UI elements with transparent backgrounds
  hi Normal guibg=NONE guifg=#FFFFFF gui=NONE cterm=NONE
  hi Pmenu guibg=#B19084 guifg=#FFFFFF gui=NONE cterm=NONE
  hi StatusLine guifg=#FFFFFF guibg=#B19084 gui=NONE cterm=NONE
  hi StatusLineNC guifg=#FFFFFF guibg=#525062 gui=NONE cterm=NONE
  hi VertSplit guifg=#6565A3 guibg=NONE gui=NONE cterm=NONE
  hi LineNr guifg=#6565A3 guibg=NONE gui=NONE cterm=NONE
  hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi FoldColumn guifg=#FFFFFF guibg=NONE gui=NONE cterm=NONE
  
  " NeoTree with transparent background including unfocused state
  hi NeoTreeNormal guibg=NONE guifg=#FFFFFF gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#FFFFFF gui=NONE cterm=NONE
  hi NeoTreeFloatNormal guibg=NONE guifg=#FFFFFF gui=NONE cterm=NONE
  hi NeoTreeFloatBorder guifg=#6565A3 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeWinSeparator guifg=#525062 guibg=NONE gui=NONE cterm=NONE
  
  " NeoTree with transparent background
  hi NeoTreeNormal guibg=NONE guifg=#FFFFFF gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#FFFFFF gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#CCCCFF guibg=NONE gui=bold cterm=bold
  
  " TabLine highlighting with complementary accents
  hi TabLine guifg=#FFFFFF guibg=#B19084 gui=NONE cterm=NONE
  hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi TabLineSel guifg=#2A2A3A guibg=#CCCCFF gui=bold cterm=bold
  hi TabLineSeparator guifg=#6565A3 guibg=#B19084 gui=NONE cterm=NONE
  
  " Interactive elements with dynamic contrast
  hi Search guifg=#525062 guibg=#AAAAF0 gui=NONE cterm=NONE
  hi Visual guifg=#525062 guibg=#9A9AE6 gui=NONE cterm=NONE
  hi MatchParen guifg=#525062 guibg=#CCCCFF gui=bold cterm=bold
  
  " Menu item hover highlight
  hi CmpItemAbbrMatch guifg=#CCCCFF guibg=NONE gui=bold cterm=bold
  hi CmpItemAbbrMatchFuzzy guifg=#AAAAF0 guibg=NONE gui=bold cterm=bold
  hi CmpItemMenu guifg=#FFFFFF guibg=NONE gui=italic cterm=italic
  hi CmpItemAbbr guifg=#FFFFFF guibg=NONE gui=NONE cterm=NONE
  hi CmpItemAbbrDeprecated guifg=#101010 guibg=NONE gui=strikethrough cterm=strikethrough
  
  " Specific menu highlight groups
  hi WhichKey guifg=#CCCCFF guibg=NONE gui=NONE cterm=NONE
  hi WhichKeySeperator guifg=#101010 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyGroup guifg=#9A9AE6 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyDesc guifg=#AAAAF0 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyFloat guibg=#525062 guifg=NONE gui=NONE cterm=NONE
  
  " Selection and hover highlights with inverted colors
  hi CursorColumn guifg=NONE guibg=#B19084 gui=NONE cterm=NONE
  hi Cursor guibg=#FFFFFF guifg=#2A2A3A gui=NONE cterm=NONE
  hi lCursor guibg=#FFFFFF guifg=#2A2A3A gui=NONE cterm=NONE
  hi CursorIM guibg=#FFFFFF guifg=#2A2A3A gui=NONE cterm=NONE
  hi TermCursor guibg=#FFFFFF guifg=#2A2A3A gui=NONE cterm=NONE
  hi TermCursorNC guibg=#FFFFFF guifg=#2A2A3A gui=NONE cterm=NONE
  hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
  hi CursorLineNr guifg=#CCCCFF guibg=NONE gui=bold cterm=bold
  
  hi QuickFixLine guifg=#525062 guibg=#9A9AE6 gui=NONE cterm=NONE
  hi IncSearch guifg=#525062 guibg=#CCCCFF gui=NONE cterm=NONE
  hi NormalNC guibg=#525062 guifg=#FFFFFF gui=NONE cterm=NONE
  hi Directory guifg=#AAAAF0 guibg=NONE gui=NONE cterm=NONE
  hi WildMenu guifg=#525062 guibg=#CCCCFF gui=bold cterm=bold
  
  " Add highlight groups for focused items with inverted colors
  hi CursorLineFold guifg=#CCCCFF guibg=#525062 gui=NONE cterm=NONE
  hi FoldColumn guifg=#FFFFFF guibg=NONE gui=NONE cterm=NONE
  hi Folded guifg=#FFFFFF guibg=#B19084 gui=italic cterm=italic

  " File explorer specific highlights
  hi NeoTreeNormal guibg=NONE guifg=#FFFFFF gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#FFFFFF gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#CCCCFF guibg=NONE gui=bold cterm=bold
  hi NeoTreeFileName guifg=#FFFFFF guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeFileIcon guifg=#AAAAF0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryName guifg=#AAAAF0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryIcon guifg=#AAAAF0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitModified guifg=#9A9AE6 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitAdded guifg=#7A7AC2 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitDeleted guifg=#A38465 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitUntracked guifg=#C28D7A guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeIndentMarker guifg=#57578F guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeSymbolicLinkTarget guifg=#9A9AE6 guibg=NONE gui=NONE cterm=NONE

  " File explorer cursor highlights with strong contrast
  " hi NeoTreeCursorLine guibg=#9A9AE6 guifg=#2A2A3A gui=bold cterm=bold
  " hi! link NeoTreeCursor NeoTreeCursorLine
  " hi! link NeoTreeCursorLineSign NeoTreeCursorLine

  " Use wallbash colors for explorer snack in dark mode
  hi WinBar guifg=#FFFFFF guibg=#B19084 gui=bold cterm=bold
  hi WinBarNC guifg=#FFFFFF guibg=#525062 gui=NONE cterm=NONE
  hi ExplorerSnack guibg=#CCCCFF guifg=#2A2A3A gui=bold cterm=bold
  hi BufferTabpageFill guibg=#2A2A3A guifg=#101010 gui=NONE cterm=NONE
  hi BufferCurrent guifg=#FFFFFF guibg=#CCCCFF gui=bold cterm=bold
  hi BufferCurrentMod guifg=#FFFFFF guibg=#9A9AE6 gui=bold cterm=bold
  hi BufferCurrentSign guifg=#CCCCFF guibg=#525062 gui=NONE cterm=NONE
  hi BufferVisible guifg=#FFFFFF guibg=#B19084 gui=NONE cterm=NONE
  hi BufferVisibleMod guifg=#FFFFFF guibg=#B19084 gui=NONE cterm=NONE
  hi BufferVisibleSign guifg=#9A9AE6 guibg=#525062 gui=NONE cterm=NONE
  hi BufferInactive guifg=#101010 guibg=#525062 gui=NONE cterm=NONE
  hi BufferInactiveMod guifg=#6565A3 guibg=#525062 gui=NONE cterm=NONE
  hi BufferInactiveSign guifg=#6565A3 guibg=#525062 gui=NONE cterm=NONE
  
  " Fix link colors to make them more visible
  hi link Hyperlink NONE
  hi link markdownLinkText NONE
  hi Underlined guifg=#FF00FF guibg=NONE gui=bold,underline cterm=bold,underline
  hi Special guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownUrl guifg=#FF00FF guibg=NONE gui=underline cterm=underline 
  hi markdownLinkText guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi htmlLink guifg=#FF00FF guibg=NONE gui=bold,underline cterm=bold,underline
  
  " Add more direct highlights for badges in markdown
  hi markdownH1 guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownLinkDelimiter guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownLinkTextDelimiter guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownIdDeclaration guifg=#FF00FF guibg=NONE gui=bold cterm=bold
else
  " Light theme with transparent backgrounds
  hi Normal guibg=NONE guifg=#2A2A3A gui=NONE cterm=NONE
  hi Pmenu guibg=#101010 guifg=#2A2A3A gui=NONE cterm=NONE
  hi StatusLine guifg=#FFFFFF guibg=#7D584B gui=NONE cterm=NONE
  hi StatusLineNC guifg=#2A2A3A guibg=#FFFFFF gui=NONE cterm=NONE
  hi VertSplit guifg=#7D584B guibg=NONE gui=NONE cterm=NONE
  hi LineNr guifg=#7D584B guibg=NONE gui=NONE cterm=NONE
  hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi FoldColumn guifg=#525062 guibg=NONE gui=NONE cterm=NONE
  
  " NeoTree with transparent background including unfocused state
  hi NeoTreeNormal guibg=NONE guifg=#2A2A3A gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#2A2A3A gui=NONE cterm=NONE
  hi NeoTreeFloatNormal guibg=NONE guifg=#2A2A3A gui=NONE cterm=NONE
  hi NeoTreeFloatBorder guifg=#514B7D guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeWinSeparator guifg=#FFFFFF guibg=NONE gui=NONE cterm=NONE
  
  " NeoTree with transparent background
  hi NeoTreeNormal guibg=NONE guifg=#2A2A3A gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#2A2A3A gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#2D2952 guibg=NONE gui=bold cterm=bold
  
  " TabLine highlighting with complementary accents
  hi TabLine guifg=#2A2A3A guibg=#FFFFFF gui=NONE cterm=NONE
  hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi TabLineSel guifg=#FFFFFF guibg=#2D2952 gui=bold cterm=bold
  hi TabLineSeparator guifg=#7D584B guibg=#FFFFFF gui=NONE cterm=NONE
  
  " Interactive elements with complementary contrast
  hi Search guifg=#FFFFFF guibg=#3F3A6B gui=NONE cterm=NONE
  hi Visual guifg=#FFFFFF guibg=#7D584B gui=NONE cterm=NONE
  hi MatchParen guifg=#FFFFFF guibg=#2D2952 gui=bold cterm=bold
  
  " Menu item hover highlight
  hi CmpItemAbbrMatch guifg=#2D2952 guibg=NONE gui=bold cterm=bold
  hi CmpItemAbbrMatchFuzzy guifg=#3F3A6B guibg=NONE gui=bold cterm=bold
  hi CmpItemMenu guifg=#525062 guibg=NONE gui=italic cterm=italic
  hi CmpItemAbbr guifg=#2A2A3A guibg=NONE gui=NONE cterm=NONE
  hi CmpItemAbbrDeprecated guifg=#B19084 guibg=NONE gui=strikethrough cterm=strikethrough
  
  " Specific menu highlight groups
  hi WhichKey guifg=#2D2952 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeySeperator guifg=#B19084 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyGroup guifg=#514B7D guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyDesc guifg=#3F3A6B guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyFloat guibg=#FFFFFF guifg=NONE gui=NONE cterm=NONE
  
  " Selection and hover highlights with inverted colors
  hi CursorColumn guifg=NONE guibg=#101010 gui=NONE cterm=NONE
  hi Cursor guibg=#2A2A3A guifg=#FFFFFF gui=NONE cterm=NONE
  hi lCursor guibg=#FFFFFF guifg=#2A2A3A gui=NONE cterm=NONE
  hi CursorIM guibg=#FFFFFF guifg=#2A2A3A gui=NONE cterm=NONE
  hi TermCursor guibg=#2A2A3A guifg=#FFFFFF gui=NONE cterm=NONE
  hi TermCursorNC guibg=#FFFFFF guifg=#2A2A3A gui=NONE cterm=NONE
  hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
  hi CursorLineNr guifg=#2D2952 guibg=NONE gui=bold cterm=bold
  
  hi QuickFixLine guifg=#FFFFFF guibg=#3F3A6B gui=NONE cterm=NONE
  hi IncSearch guifg=#FFFFFF guibg=#2D2952 gui=NONE cterm=NONE
  hi NormalNC guibg=#FFFFFF guifg=#525062 gui=NONE cterm=NONE
  hi Directory guifg=#2D2952 guibg=NONE gui=NONE cterm=NONE
  hi WildMenu guifg=#FFFFFF guibg=#2D2952 gui=bold cterm=bold
  
  " Add highlight groups for focused items with inverted colors
  hi CursorLineFold guifg=#2D2952 guibg=#FFFFFF gui=NONE cterm=NONE
  hi FoldColumn guifg=#525062 guibg=NONE gui=NONE cterm=NONE
  hi Folded guifg=#2A2A3A guibg=#101010 gui=italic cterm=italic

  " File explorer specific highlights
  hi NeoTreeNormal guibg=NONE guifg=#2A2A3A gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#2A2A3A gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#2D2952 guibg=NONE gui=bold cterm=bold
  hi NeoTreeFileName guifg=#2A2A3A guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeFileIcon guifg=#3F3A6B guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryName guifg=#3F3A6B guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryIcon guifg=#3F3A6B guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitModified guifg=#514B7D guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitAdded guifg=#8F6657 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitDeleted guifg=#A38465 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitUntracked guifg=#C28D7A guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeIndentMarker guifg=#5D578F guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeSymbolicLinkTarget guifg=#514B7D guibg=NONE gui=NONE cterm=NONE

  " File explorer cursor highlights with strong contrast
  " hi NeoTreeCursorLine guibg=#3F3A6B guifg=#FFFFFF gui=bold cterm=bold
  " hi! link NeoTreeCursor NeoTreeCursorLine
  " hi! link NeoTreeCursorLineSign NeoTreeCursorLine

  " Use wallbash colors for explorer snack in light mode
  hi WinBar guifg=#2A2A3A guibg=#101010 gui=bold cterm=bold
  hi WinBarNC guifg=#525062 guibg=#FFFFFF gui=NONE cterm=NONE
  hi ExplorerSnack guibg=#2D2952 guifg=#FFFFFF gui=bold cterm=bold
  hi BufferTabpageFill guibg=#FFFFFF guifg=#B19084 gui=NONE cterm=NONE
  hi BufferCurrent guifg=#FFFFFF guibg=#2D2952 gui=bold cterm=bold
  hi BufferCurrentMod guifg=#FFFFFF guibg=#514B7D gui=bold cterm=bold
  hi BufferCurrentSign guifg=#2D2952 guibg=#FFFFFF gui=NONE cterm=NONE
  hi BufferVisible guifg=#2A2A3A guibg=#101010 gui=NONE cterm=NONE
  hi BufferVisibleMod guifg=#525062 guibg=#101010 gui=NONE cterm=NONE
  hi BufferVisibleSign guifg=#514B7D guibg=#FFFFFF gui=NONE cterm=NONE
  hi BufferInactive guifg=#B19084 guibg=#FFFFFF gui=NONE cterm=NONE
  hi BufferInactiveMod guifg=#6C65A3 guibg=#FFFFFF gui=NONE cterm=NONE
  hi BufferInactiveSign guifg=#6C65A3 guibg=#FFFFFF gui=NONE cterm=NONE
  
  " Fix link colors to make them more visible
  hi link Hyperlink NONE
  hi link markdownLinkText NONE
  hi Underlined guifg=#FF00FF guibg=NONE gui=bold,underline cterm=bold,underline
  hi Special guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownUrl guifg=#FF00FF guibg=NONE gui=underline cterm=underline 
  hi markdownLinkText guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi htmlLink guifg=#FF00FF guibg=NONE gui=bold,underline cterm=bold,underline
  
  " Add more direct highlights for badges in markdown
  hi markdownH1 guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownLinkDelimiter guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownLinkTextDelimiter guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownIdDeclaration guifg=#FF00FF guibg=NONE gui=bold cterm=bold
endif

" UI elements that are the same in both themes with transparent backgrounds
hi NormalFloat guibg=NONE guifg=NONE gui=NONE cterm=NONE
hi FloatBorder guifg=#7D584B guibg=NONE gui=NONE cterm=NONE
hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
hi DiffAdd guifg=#FFFFFF guibg=#7A7AC2 gui=NONE cterm=NONE
hi DiffChange guifg=#FFFFFF guibg=#A37665 gui=NONE cterm=NONE
hi DiffDelete guifg=#FFFFFF guibg=#A38465 gui=NONE cterm=NONE
hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE

" Fix selection highlighting with proper color derivatives
hi TelescopeSelection guibg=#FFDACC guifg=#2A2A3A gui=bold cterm=bold
hi TelescopeSelectionCaret guifg=#FFFFFF guibg=#FFDACC gui=bold cterm=bold
hi TelescopeMultiSelection guibg=#E6AE9A guifg=#2A2A3A gui=bold cterm=bold
hi TelescopeMatching guifg=#C29D7A guibg=NONE gui=bold cterm=bold

" Minimal fix for explorer selection highlighting
hi NeoTreeCursorLine guibg=#FFDACC guifg=#2A2A3A gui=bold

" Fix for LazyVim menu selection highlighting
hi Visual guibg=#FFE5CC guifg=#2A2A3A gui=bold
hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
hi PmenuSel guibg=#FFE5CC guifg=#2A2A3A gui=bold
hi WildMenu guibg=#FFE5CC guifg=#2A2A3A gui=bold

" Create improved autocommands to ensure highlighting persists with NeoTree focus fixes
augroup WallbashSelectionFix
  autocmd!
  " Force these persistent highlights with transparent backgrounds where possible
  autocmd ColorScheme * if &background == 'dark' |
    \ hi Normal guibg=NONE |
    \ hi NeoTreeNormal guibg=NONE |
    \ hi SignColumn guibg=NONE |
    \ hi NormalFloat guibg=NONE |
    \ hi FloatBorder guibg=NONE |
    \ hi TabLineFill guibg=NONE |
    \ else |
    \ hi Normal guibg=NONE |
    \ hi NeoTreeNormal guibg=NONE |
    \ hi SignColumn guibg=NONE |
    \ hi NormalFloat guibg=NONE |
    \ hi FloatBorder guibg=NONE |
    \ hi TabLineFill guibg=NONE |
    \ endif
  
  " Force NeoTree background to be transparent even when unfocused
  autocmd WinEnter,WinLeave,BufEnter,BufLeave * if &ft == 'neo-tree' || &ft == 'NvimTree' | 
    \ hi NeoTreeNormal guibg=NONE |
    \ hi NeoTreeEndOfBuffer guibg=NONE |
    \ endif
    
  " Fix NeoTree unfocus issue specifically in LazyVim
  autocmd VimEnter,ColorScheme * hi link NeoTreeNormalNC NeoTreeNormal
  
  " Make CursorLine less obtrusive by using underline instead of background
  autocmd ColorScheme * hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
  
  " Make links visible across modes
  autocmd ColorScheme * if &background == 'dark' |
    \ hi Underlined guifg=#FF00FF guibg=NONE gui=bold,underline cterm=bold,underline |
    \ hi Special guifg=#FF00FF guibg=NONE gui=bold cterm=bold |
    \ else |
    \ hi Underlined guifg=#FF00FF guibg=NONE gui=bold,underline cterm=bold,underline |
    \ hi Special guifg=#FF00FF guibg=NONE gui=bold cterm=bold |
    \ endif
  
  " Fix markdown links specifically
  autocmd FileType markdown hi markdownUrl guifg=#FF00FF guibg=NONE gui=underline,bold
  autocmd FileType markdown hi markdownLinkText guifg=#FF00FF guibg=NONE gui=bold
  autocmd FileType markdown hi markdownIdDeclaration guifg=#FF00FF guibg=NONE gui=bold
  autocmd FileType markdown hi htmlLink guifg=#FF00FF guibg=NONE gui=bold,underline
augroup END

" Create a more aggressive fix for NeoTree background in LazyVim
augroup FixNeoTreeBackground
  autocmd!
  " Force NONE background for NeoTree at various points to override tokyonight fallback
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeNormal guibg=NONE guifg=#FFFFFF ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeNormalNC guibg=NONE guifg=#FFFFFF ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeEndOfBuffer guibg=NONE guifg=#FFFFFF ctermbg=NONE
  
  " Also fix NvimTree for NvChad
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeNormal guibg=NONE guifg=#FFFFFF ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeNormalNC guibg=NONE guifg=#FFFFFF ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeEndOfBuffer guibg=NONE guifg=#FFFFFF ctermbg=NONE
  
  " Apply highlight based on current theme
  autocmd ColorScheme,VimEnter * if &background == 'dark' |
    \ hi NeoTreeCursorLine guibg=#FFDACC guifg=#2A2A3A gui=bold cterm=bold |
    \ hi NvimTreeCursorLine guibg=#FFDACC guifg=#2A2A3A gui=bold cterm=bold |
    \ else |
    \ hi NeoTreeCursorLine guibg=#2D2952 guifg=#FFFFFF gui=bold cterm=bold |
    \ hi NvimTreeCursorLine guibg=#2D2952 guifg=#FFFFFF gui=bold cterm=bold |
    \ endif
  
  " Force execution after other plugins have loaded
  autocmd VimEnter * doautocmd ColorScheme
augroup END

" Add custom autocommand specifically for LazyVim markdown links
augroup LazyVimMarkdownFix
  autocmd!
  " Force link visibility in LazyVim with stronger override
  autocmd FileType markdown,markdown.mdx,markdown.gfm hi! def link markdownUrl MagentaLink
  autocmd FileType markdown,markdown.mdx,markdown.gfm hi! def link markdownLinkText MagentaLink
  autocmd FileType markdown,markdown.mdx,markdown.gfm hi! def link markdownLink MagentaLink
  autocmd FileType markdown,markdown.mdx,markdown.gfm hi! def link markdownLinkDelimiter MagentaLink
  autocmd FileType markdown,markdown.mdx,markdown.gfm hi! MagentaLink guifg=#FF00FF gui=bold,underline
  
  " Apply when LazyVim is detected
  autocmd User LazyVimStarted doautocmd FileType markdown
  autocmd VimEnter * if exists('g:loaded_lazy') | doautocmd FileType markdown | endif
augroup END

" Add custom autocommand specifically for markdown files with links
augroup MarkdownLinkFix
  autocmd!
  " Use bright hardcoded magenta that will definitely be visible
  autocmd FileType markdown hi markdownUrl guifg=#FF00FF guibg=NONE gui=underline,bold
  autocmd FileType markdown hi markdownLinkText guifg=#FF00FF guibg=NONE gui=bold
  autocmd FileType markdown hi markdownIdDeclaration guifg=#FF00FF guibg=NONE gui=bold
  autocmd FileType markdown hi htmlLink guifg=#FF00FF guibg=NONE gui=bold,underline
  
  " Force these highlights right after vim loads
  autocmd VimEnter * if &ft == 'markdown' | doautocmd FileType markdown | endif
augroup END

" Remove possibly conflicting previous autocommands
augroup LazyVimFix
  autocmd!
augroup END

augroup MinimalExplorerFix
  autocmd!
augroup END
