/* The iOS app's entry: the game's code is runtime/ (ios_app.m holds the
 * application and scene delegates), linked from out/ios by ios/build.sh. */
int nfsu2_ios_run(int argc, char **argv);
int main(int argc, char **argv){ return nfsu2_ios_run(argc, argv); }
