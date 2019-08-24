var gulp = require('gulp');

var browserify = require('gulp-browserify');
var coffeeify = require('gulp-coffeeify');
var coffee = require('gulp-coffee');
var concat = require('gulp-concat');
var sass = require('gulp-sass');
var pug = require('gulp-pug');
var plumber = require('gulp-plumber');
var replace = require('gulp-replace');

var lr = require('gulp-livereload');

var resolve = require('resolve');


var paths = {
  scripts: ['app/client/coffee/**/*.coffee'],
  styles:  ['app/client/sass/fonts.sass', 'app/client/sass/tossup.sass','app/client/sass/gloss.sass','app/client/sass/**/*.sass',
    'node_modules/datatables.net-dt/css/jquery.dataTables.css'],
  views:   ['app/client/jade/**/*.jade'],
  data:    ['app/data/**/*']
};

gulp.task('scripts', function () {
  return gulp.src(paths.scripts)
    .pipe(plumber())
    .pipe(coffeeify({
      debug: true
    }))
    .pipe(concat('all.js'))
    .pipe(replace(/sourceMappingURL/g, 'sourceFaffingURL'))
    .pipe(gulp.dest('dist/js'))
    .pipe(lr());
});

/*gulp.task('scripts-app', function () {
  return gulp.src(paths.scripts)
    .pipe(plumber())
    .pipe(coffeeify({
      debug: true
    }))
    .pipe(concat('all.js'))
    .pipe(gulp.dest('dist/js'))
    .pipe(lr());
});

var npmDependencies = Object.keys(require('./package.json').dependencies);

gulp.task('scripts-vendor', function() {
  var b = coffeeify({
    debug: false
  });
  npmDependencies.forEach(function (id) {
    b.require(resolve.sync(id), { expose: id });
  });
  return b.bundle()
    .pipe(concat('vendor.js'))
    .pipe(gulp.dest('dist/js'));
});

gulp.task('scripts', ['scripts-app', 'scripts-vendor']);*/

gulp.task('styles', function () {
  return gulp.src(paths.styles)
    .pipe(plumber())
    .pipe(sass())
    .pipe(concat('all.css'))
    .pipe(gulp.dest('dist/css'))
    .pipe(lr());
});

gulp.task('views', function () {
  return gulp.src(paths.views)
    .pipe(plumber())
    .pipe(pug())
    .pipe(gulp.dest('dist'))
    .pipe(lr());
});

gulp.task('copy', function() {
  return gulp.src(paths.data)
    .pipe(gulp.dest('dist/data'));
});

gulp.task('build', gulp.parallel('scripts', 'styles', 'views', 'copy'));

gulp.task('watch', function () {
  lr.listen();
  gulp.watch(paths.scripts, gulp.series('scripts'));
  gulp.watch(paths.styles,  gulp.series('styles'));
  gulp.watch(paths.views,   gulp.series('views'));
});
