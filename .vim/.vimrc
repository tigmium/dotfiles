let s:is_win   = has('win32') || has('win64')

if s:is_win
  set shell=cmd
endif

let s:is_mingw = system('uname') =~? '^MINGW'
let s:is_mac   = has('mac') || system('uname') =~? '^darwin'
let s:is_linux = !s:is_mac && has('unix')

set encoding=UTF-8
set fileencoding=utf-8
set fileencodings=utf-8,euc-jp,cp932
" set termencoding=UTF-8
if s:is_win || s:is_mingw
  " set termencoding=cp932
endif
scriptencoding utf-8

" Utility Functions"{{{
function! s:warn(msg)
  echohl WarningMsg | echo a:msg | echohl None
endfunction

" Vim起動時に表示するメッセージ
" vimrc内でバッファを作成すると確認メッセージが抑制できなかったため
" 起動イベントをフックして表示する
let s:informations = []

function! s:info(msg)
  call add(s:informations, a:msg)
endfunction

function! s:show_info()
  let l:has_info = len(s:informations)
  while len(s:informations) > 0
    call s:show_info_line(remove(s:informations, 0))
  endwhile
  if l:has_info != 0
    call s:warn('メッセージがあります。"message"コマンドで確認してください。')
  endif
endfunction

function! s:show_info_line(msg)
  echomsg string(a:msg)
endfunction

augroup ShowInfo
  au!
  autocmd VimEnter * call s:show_info()
augroup END

function! s:setup_tmp_buf()
  setlocal buftype=nowrite
  setlocal noswapfile
  setlocal bufhidden=wipe
  setlocal nonumber
  setlocal nowrap
  setlocal nocursorline
  setlocal nocursorcolumn
endfunction

function! s:depend_cui_tool(cmd, ...)
  let l:able = executable(a:cmd)
  if !l:able
    call s:info('コマンドラインツール「' . a:cmd . '」が見つかりません')
    if exists('a:1')
      call s:info(a:1)
    endif
  endif
  return l:able
endfunction

function! s:to_camel(str)
  let l:words = split(a:str, '\W\+')
  call map(l:words, 'toupper(v:val[0]) . v:val[1:]')
  return join(l:words, '')
endfunction

function! s:to_snake(str)
  let l:words = split(a:str, '\W\+')
  call map(l:words, 'tolower(v:val)')
  return join(l:words, '_')
endfunction

function! s:line_info()
  let name     = expand('%:t')
  let line_no  = line('.')
  let line_str = getline(line_no)
  redir @*>
  echo printf('%s:%d %s', name, line_no, line_str)
  redir END
endfunction

function! s:provide_tab_label()
  let l:label = ''
  let l:bufnrlist = tabpagebuflist(v:lnum)
  let l:bufname = fnamemodify(bufname(l:bufnrlist[tabpagewinnr(v:lnum) - 1]), ':t')
  let l:label .= l:bufname == '' ? 'No title' : l:bufname

  for bufnr in l:bufnrlist
    if getbufvar(bufnr, '&modified')
      let l:label .= '[+]'
      break
    endif
  endfor

  return l:label
endfunction

function! s:get_outerdoc_name()
  let l:path = expand('%:p')
  return substitute(l:path, '/\|:', '_', 'g') . '.md'
endfunction

function! s:setup_source_buffer()
  setlocal cursorbind
endfunction

function! s:setup_outerdoc_buffer()
  setlocal cursorbind
endfunction

function! s:create_outerdoc_dir(path)
  let l:outerdoc_dir = fnamemodify(a:path, ':h')
  if !isdirectory(l:outerdoc_dir)
    call mkdir(l:outerdoc_dir, 'p')
  endif
endfunction

function! s:fill_in_blank_line(path, count_line)
  let l:blank_lines = map(range(a:count_line), '""')
  call writefile(l:blank_lines, a:path)
endfunction

function! s:prepare_outerdoc(path, count_line)
  if !filewritable(a:path)
    call s:create_outerdoc_dir(a:path)
    call s:fill_in_blank_line(a:path, a:count_line)
  endif
endfunction

function! s:open_outerdoc_buffer(path, cursor_line)
  belowright 50vnew `=a:path`
  execute ':normal ' . a:cursor_line . 'G'
endfunction

function! s:outerdoc_open()
  let l:count_line = line('$')
  let l:cursor_line = line('.')
  let l:outerdoc_path = expand('~/.outerdoc/' . s:get_outerdoc_name())

  call s:setup_source_buffer()
  call s:prepare_outerdoc(l:outerdoc_path, l:count_line)
  call s:open_outerdoc_buffer(l:outerdoc_path, l:cursor_line)
  call s:setup_outerdoc_buffer()
endfunction

command! OuterDocOpen call s:outerdoc_open()

function! s:ch_buf_name(name)
  file `=a:name`
endfunction

command! -nargs=+ ChangeBufferName :call s:ch_buf_name(<f-args>)

" Codic Complete "{{{
" https://gist.github.com/sgur/4e1cc8e93798b8fe9621
" http://sgur.tumblr.com/post/91906146884/codic-vim
inoremap <silent> <C-x><C-t>  <C-R>=<SID>codic_complete()<CR>
function! s:codic_complete()
  let line = getline('.')
  let start = match(line, '\k\+$')
  let cand = s:codic_candidates(line[start :])
  call complete(start +1, cand)
  return ''
endfunction
function! s:codic_candidates(arglead)
  let cand = codic#search(a:arglead, 30)
  " error
  if type(cand) == type(0)
    return []
  endif
  " english -> english terms
  if a:arglead =~# '^\w\+$'
    return map(cand, '{"word": v:val["label"], "menu": join(map(copy(v:val["values"]), "v:val.word"), ",")}')
  endif
  " japanese -> english terms
  return s:reverse_candidates(cand)
endfunction
function! s:reverse_candidates(cand)
  let _ = []
  for c in a:cand
    for v in c.values
      call add(_, {'word': v.word, 'menu': !empty(v.desc) ? v.desc : c.label })
    endfor
  endfor
  return _
endfunction
"}}}
"}}}

" Plugins"{{{
if &compatible
  set nocompatible               " Be iMproved
endif

" Required:
set runtimepath^=~/.cache/dein/repos/github.com/Shougo/dein.vim

" Required:
call dein#begin(expand('~/.cache/dein'))

" Let dein manage dein
" Required:
call dein#add('Shougo/dein.vim')

let s:toml_path = '~/dotfiles/dein.toml'
let s:toml_lazy_path = '~/dotfiles/deinlazy.toml'

call dein#load_toml(s:toml_path, {'lazy': 0})
call dein#load_toml(s:toml_lazy_path, {'lazy' : 1})

" Required:
call dein#end()

" Required:
filetype plugin indent on

" If you want to install not installed plugins on startup.
if dein#check_install(['vimproc.vim'])
  call dein#install('vimproc.vim')
endif

if dein#check_install()
  call dein#install()
endif
"}}}

" Key Binds"{{{
let mapleader = ' '

nnoremap <esc> :noh<cr>

nnoremap <Leader>v :tabnew ~/.vimrc<cr>

imap <S-Enter> <ESC>

" タブ切り替え
nnoremap 1<Leader> 1gt
nnoremap 2<Leader> 2gt
nnoremap 3<Leader> 3gt
nnoremap 4<Leader> 4gt
nnoremap 5<Leader> 5gt
nnoremap 6<Leader> 6gt
nnoremap 7<Leader> 7gt
nnoremap 8<Leader> 8gt
nnoremap 9<Leader> 9gt
nnoremap <silent> gl gt
nnoremap <silent> gh gT

" ウィンドウ切り替え
nnoremap <silent> gj <C-w>w
nnoremap <silent> gk <C-w>W
nnoremap <C-J> <C-w>w
nnoremap <C-K> <C-w>W

nnoremap <silent> <C-j> }
nnoremap <silent> <C-k> {

nnoremap <silent> , :VimShellTab<cr>

nnoremap [unite] <Nop>
nmap     <Leader>u [unite]
" nnoremap <silent> [unite]m :Unite mark<cr>
" nnoremap <silent> [unite]y :Unite history/yank<cr>
" nnoremap <silent> [unite]B :Unite bookmark<cr>
nnoremap <silent> [unite]q :Unite -tab -max-multi-lines=1 quickfix<cr>
nnoremap <silent> [unite]g :Unite grep/git -no-quit -tab -buffer-name=grep-git -default-action=tabopen<cr>
nnoremap <silent> <C-f> :Unite -start-insert outline<cr>

nnoremap <silent> <C-@> :CtrlPBuffer<cr>

nmap <Leader>r <Plug>(quickrun)

nmap s         <Plug>(easymotion-s2)
vmap s         <Plug>(easymotion-s2)
nmap <Leader>j <Plug>(easymotion-j)
nmap <Leader>k <Plug>(easymotion-k)
vmap <Leader>j <Plug>(easymotion-j)
vmap <Leader>k <Plug>(easymotion-k)

nmap <Leader>c <Plug>(caw:i:toggle)
vmap <Leader>c <Plug>(caw:i:toggle)

vmap <cr> <Plug>(EasyAlign)

" nmap <Leader>m <Plug>(quickhl-manual-this)
" xmap <Leader>m <Plug>(quickhl-manual-this)
" nmap <Leader>M <Plug>(quickhl-manual-reset)
" xmap <Leader>M <Plug>(quickhl-manual-reset)
"
" nmap <Leader>h <Plug>(quickhl-cword-toggle)
" nmap <Leader>] <Plug>(quickhl-tag-toggle)

nmap ys <Plug>(operator-surround-append)
nmap ds <Plug>(operator-surround-delete)
nmap cs <Plug>(operator-surround-replace)

nnoremap [git] <Nop>
nmap     <Leader>g [git]
nnoremap <silent> [git]s :Gstatus<cr>
nnoremap <silent> [git]l :AgitFile<cr>
nnoremap <silent> [git]L :Agit<cr>

imap <C-k> <Plug>(neosnippet_expand_or_jump)
smap <C-k> <Plug>(neosnippet_expand_or_jump)
xmap <C-k> <Plug>(neosnippet_expand_target)
imap <expr><TAB> neosnippet#expandable_or_jumpable() ?
      \ "\<Plug>(neosnippet_expand_or_jump)"
      \: pumvisible() ? "\<C-n>" : "\<TAB>"
smap <expr><TAB> neosnippet#expandable_or_jumpable() ?
      \ "\<Plug>(neosnippet_expand_or_jump)"
      \: "\<TAB>"
if has('conceal')
  set conceallevel=2 concealcursor=i
endif

nmap n n<Plug>(anzu-update-search-status)
nmap N N<Plug>(anzu-update-search-status)
map * <Plug>(asterisk-z*)<Plug>(anzu-update-search-status)

if !has('gui_running')
  set pastetoggle=<F12>

  augroup DisablePaste
    autocmd!
    autocmd InsertLeave * set nopaste
  augroup END
endif

" clear status
nmap <Esc><Esc> <Plug>(anzu-clear-search-status)

" if executable('fcitx-remote')
"   inoremap <esc> <esc>:CloseFcitx<cr>
"   command! CloseFcitx :call system("fcitx-remote -c")
" endif

nmap <Leader>p <Plug>(operator-replace)
"}}}

" Options"{{{
" if has('vim_starting') 
"   if executable('xset')
"     call system('xset r rate 200 30')
"   endif
" endif

" Google 翻訳
if s:depend_cui_tool('trans', 'https://github.com/soimort/translate-shell')
  set keywordprg=trans\ :ja
endif

" フォント
if s:is_win
  " set guifont=Consolas:h11:cANSI
endif
set ambiwidth=double
" set antialias

colorscheme darkblue

" ファイル形式に応じて色づけ
syntax enable

" 検索
set ignorecase
set smartcase
set incsearch
set hlsearch

set nrformats=hex

" ファイルパスの区切り文字
" set noshellslash

" クリップボード
set clipboard=unnamedplus,unnamed

" バックアップファイル
set nobackup

" スワップファイル
set noswapfile
set directory=~/.vim/tmp

" アンドゥファイル
set noundofile

" シェル
" if s:is_mingw
"   set termencoding=UTF-8
"   set shell=E:/Software/Mingw/msys/1.0/bin/mintty\ /bin/bash\ -l
"   set shellcmdflag=-c
" endif

" 行数・列数
if s:is_win
  " set lines=60
  " set columns=110
endif

" マウス
set mouse=h

" ステータスの表示
set laststatus=2
" set statusline=%<%f\ %m%r%h%w%{'['.(&fenc!=''?&fenc:&enc).']['.&ff.']'}%=%l,%c%V%8P

" 行番号を表示
set number

" 行・列のハイライト
set nocursorline
set nocursorcolumn

" 行を常に中央に
" set scrolloff=999

" 折り返しを禁止
set nowrap

" 対応する括弧を強調表示
set showmatch

" タブ・インデント
set expandtab " タブをスペースに変換する
set tabstop=4 " タブをスペース何個で表示するか
set shiftwidth=4 " >>などで挿入される量
set softtabstop=0 " タブを押した時の挿入量 0の場合tabstopの値になる。
set autoindent

" タブ、空白、改行の可視化
set list
set listchars=tab:>.,trail:_,eol:↲,extends:>,precedes:<,nbsp:%

" カレントディレクトリの自動切換え
set noautochdir

" タブページを常に表示
set showtabline=2
" gVimでもテキストベースのタブページを使う
set guioptions-=e
" タブの表示
set guitablabel=%N:\ %{s:provide_tab_label()}

" GUIオプション
set guioptions-=T
set guioptions-=m
set guioptions-=r

" 折り畳み
set foldmethod=marker

" ターミナルの色数
if !has('gui_running')
  set t_Co=256
endif

" カラースキーム
if s:is_win
  colorscheme default
else
  set background=dark
  if dein#tap('vim-colors-solarized')
    colorscheme solarized
  endif
endif

" ファイル名補完
set wildmode=list:full

" ファイル/ディレクトリ補完で無視されるファイルパターン
set wildignore+=*/tmp/*,*.so,*.swp,*.zip,*.jpg,*.png

" .vimrc.local読み込み
augroup vimrc-local
  autocmd!
  autocmd BufNewFile,BufReadPost * call s:vimrc_local(expand('<afile>:p:h'))
augroup END

function! s:vimrc_local(loc)
  let files = findfile('.vimrc.local', escape(a:loc, ' ') . ';', -1)
  for i in reverse(filter(files, 'filereadable(v:val)'))
    source `=i`
  endfor
endfunction
"}}}
