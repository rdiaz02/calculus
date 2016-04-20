#
#
# See comments at the top of gen_graph.rb for notes about
# figures, fonts, lulu, etc.
#
#
#

BOOK = calc
MODE = nonstopmode
TERMINAL_OUTPUT = err

MAKEINDEX = makeindex $(BOOK).idx

DO_PDFLATEX_RAW = pdflatex -interaction=$(MODE) $(BOOK) >$(TERMINAL_OUTPUT)
SHOW_ERRORS = \
        print "========error========\n"; \
        open(F,"$(TERMINAL_OUTPUT)"); \
        while ($$line = <F>) { \
          if ($$line=~m/^\! / || $$line=~m/^l.\d+ /) { \
            print $$line \
          } \
        } \
        close F; \
        exit(1)
DO_PDFLATEX = echo "$(DO_PDFLATEX_RAW)" ; perl -e 'if (system("$(DO_PDFLATEX_RAW)")) {$(SHOW_ERRORS)}'
GENERIC_OPTIONS_FOR_CALIBRE =  --authors "Benjamin Crowell" --language en --title "Brief Calculus" --toc-filter="[0-9]\.[0-9]"
WEB_DIR = /home/bcrowell/Lightandmatter/calc
PROBLEMS_CSV = problems.csv

# Since book1 comes first, it's the default target --- you can just do ``make'' to make it.

book1:
	@make preflight
	@scripts/translate_to_html.rb --write_config_and_exit
	@$(DO_PDFLATEX)
	@scripts/translate_to_html.rb --util="learn_commands:$(BOOK).cmd"
	@scripts/harvest_aux_files.rb
	@rm -f $(TERMINAL_OUTPUT) # If pdflatex has a nonzero exit code, we don't get here, so the output file is available for inspection.

all:
	make book
	make post
	make web
	make handheld
	make post_handheld

index:
	$(MAKEINDEX)

book:
	@make preflight
	@scripts/translate_to_html.rb --write_config_and_exit
	make clean
	@$(DO_PDFLATEX)
	@scripts/translate_to_html.rb --util="learn_commands:$(BOOK).cmd"
	@scripts/harvest_aux_files.rb
	@$(DO_PDFLATEX)
	@scripts/harvest_aux_files.rb
	$(MAKEINDEX)
	@$(DO_PDFLATEX)
	@scripts/harvest_aux_files.rb
	@rm -f $(TERMINAL_OUTPUT) # If pdflatex has a nonzero exit code, we don't get here, so the output file is available for inspection.

test:
	perl -e 'if (system("pdflatex -interaction=$(MODE) $(BOOK) >$(TERMINAL_OUTPUT)")) {print "error\n"} else {print "no error\n"}'

web:
	@make preflight
	@[ `which footex` ] || echo "******** footex is not installed, so html cannot be generated; get footex from http://www.lightandmatter.com/footex/footex.html"
	@[ `which footex` ] || exit 1
	@scripts/translate_to_html.rb --write_config_and_exit
	scripts/prep_web.pl
	WOPT='--html5' scripts/make_web.pl # html 5
	WOPT='--mathjax' scripts/make_web.pl # html 4 with mathjax
	scripts/make_web.pl # html 4

handheld:
	# see meki:computer:general for notes on this
	make preflight
	scripts/translate_to_html.rb --write_config_and_exit --modern --override_config_with="handheld.config"
	rm -f calc_handheld/ch*/*html calc_handheld/index.*html
	mkdir -p calc_handheld
	scripts/prep_web.pl
	WOPT='--modern --override_config_with="handheld.config"' scripts/make_web.pl
	cp standalone.css calc_handheld
	make epub
	make mobi
	make epub3
	@echo "To post the books, do 'make post_handheld'."

epub3:
	make preflight
	scripts/translate_to_html.rb --write_config_and_exit --html5 --override_config_with="handheld.config,epub3.config"
	rm -f calc_handheld/ch*/*html calc_handheld/index.html
	mkdir -p calc_handheld
	scripts/prep_web.pl
	WOPT='--html5 --override_config_with="handheld.config,epub3.config"' scripts/make_web.pl
	cp standalone.css calc_handheld
	ebook-convert calc_handheld/index.html calc_epub3.epub $(GENERIC_OPTIONS_FOR_CALIBRE) --no-default-epub-cover --cover=ch00/figs/handheld-cover.jpg
	scripts/translate_to_html.rb --override_config_with="handheld.config,epub3.config" --util="patch_epub3:calc_epub3.epub"

post_handheld:
	cp calc.epub $(WEB_DIR)
	cp calc.mobi $(WEB_DIR)
	cp calc_epub3.epub $(WEB_DIR)

epub:
	# Before doing this, do a "make handheld".
	ebook-convert calc_handheld/index.html calc.epub $(GENERIC_OPTIONS_FOR_CALIBRE) --no-default-epub-cover --cover=ch00/figs/handheld-cover.jpg

mobi:
	# Before doing this, do a "make handheld".
	#  --rescale-images no longer seems to exist in calibre 0.9
	ebook-convert calc_handheld/index.html calc.mobi $(GENERIC_OPTIONS_FOR_CALIBRE) --cover=ch00/figs/handheld-cover.jpg

epubcheck:
	java -jar /usr/bin/epubcheck/epubcheck.jar calc.epub 2>err

very_clean: clean
	rm -f calc.pdf calc_lulu.pdf
	rm -Rf calc_handheld
	rm -f learned_commands.json

clean:
	# Sometimes we get into a state where LaTeX is unhappy, and erasing these cures it:
	rm -f *aux *idx *ilg *ind *log *toc *out
	rm -f ch*/*aux
	rm -f temp.* temp_mathml.*
	# Shouldn't exist in subdirectories:
	rm -f */*.log
	# Emacs backup files:
	rm -f *~
	rm -f */*~
	# Misc:
	rm -f ch*/figs/*.eps
	rm -Rf ch*/figs/.xvpics
	rm -f a.a
	rm -f */a.a
	rm -f */*/a.a
	rm -f junk
	rm -f err
	rm -f calc_lulu.pdf calc.pdf *.epub *.mobi *.azw
	rm -f temp.pdf ch*/ch*temp.temp temp.config $(BOOK).cmd

post:
	cp calc.pdf $(WEB_DIR)

all_figures:
	perl -e 'foreach my $$f(<*/figs/*.svg>) {system("scripts/render_one_figure.pl $$f")}'

prepress:
	scripts/preflight_figs.pl
	# The following makes Lulu not complain about missing fonts:
	scripts/pdf_extract_pages.rb calc.pdf 3-end calc_lulu.pdf
	# Filtering through gs used to be necessary to convince Lulu not to complain about missing fonts.
	# Now that should no longer be necessary, because recent versions of pdftex embed all fonts, and fullembed.map prevents subsetting.
	# See meki:computer:apps:ghostscript, scripts/create_fullembed_file, and http://tex.stackexchange.com/questions/24002/turning-off-font-subsetting-in-pdftex

post_source:
	# don't forget to commit first, git commit -a -m "comment"
	# repo is hosted on github, see book's web page
	git push

preflight:
	@chmod +x scripts/* scripts/custom/* gen_graph.rb
	@perl -e 'if (-e "scripts/custom/enable") {foreach $$f(<scripts/custom/*.pl>) {$$c="$$f $(BOOK) $(PROBLEMS_CSV)"; system($$c)}}'

setup:
	chmod +x scripts/* scripts/custom/* gen_graph.rb 
	@echo "If the following command doesn't give a compiler error, you have a sufficiently up to date version of ruby."
	ruby -e 'print ("ab" =~ /(?<!a)b/)'
	@echo "If the following command doesn't give a compiler error, you have a sufficiently up to date version of libjson-perl."
	@echo "If your version of the library is too old, you can uninstall it and then install the latest version by doing 'cpan JSON'."
	perl -e 'use JSON 2.0'

figures:
	./gen_graph.rb ch*/*.tex
	# The following requires Inkscape 0.47 or later.
	perl -e 'foreach my $$f(<ch*/figs/*.svg>) {$$g=$$f; $$g=~s/\.svg$$/.pdf/; unless (-e $$g) {print "g=$$g\n"; $$c="inkscape --export-text-to-path --export-pdf=$$g $$f  --export-area-drawing"; print "$$c\n"; system($$c)}}'
