; ModuleID = 'ir_corpus.c'
source_filename = "ir_corpus.c"
target datalayout = "e-m:e-p:64:64-i64:64-i128:128-n32:64-S128"
target triple = "riscv64-unknown-linux-gnu"

@switch.table.sw = private unnamed_addr constant [3 x i32] [i32 1, i32 2, i32 4], align 4

; Function Attrs: nofree norecurse nosync nounwind optsize memory(argmem: read) uwtable vscale_range(2,1024)
define dso_local signext i32 @dot(ptr noundef readonly captures(none) %0, ptr noundef readonly captures(none) %1, i32 noundef signext %2) local_unnamed_addr #0 {
  %4 = icmp sgt i32 %2, 0
  br i1 %4, label %5, label %30

5:                                                ; preds = %3
  %6 = zext nneg i32 %2 to i64
  %7 = tail call i64 @llvm.vscale.i64()
  %8 = shl nuw nsw i64 %7, 2
  %9 = add nsw i64 %8, -1
  %10 = add nsw i64 %9, %6
  %11 = sub nsw i64 0, %8
  %12 = and i64 %10, %11
  %13 = tail call i64 @llvm.vscale.i64()
  %14 = shl nuw nsw i64 %13, 2
  br label %15

15:                                               ; preds = %15, %5
  %16 = phi i64 [ 0, %5 ], [ %25, %15 ]
  %17 = phi <vscale x 4 x i32> [ zeroinitializer, %5 ], [ %24, %15 ]
  %18 = tail call <vscale x 4 x i1> @llvm.get.active.lane.mask.nxv4i1.i64(i64 %16, i64 %6)
  %19 = getelementptr inbounds nuw i32, ptr %0, i64 %16
  %20 = tail call <vscale x 4 x i32> @llvm.masked.load.nxv4i32.p0(ptr %19, i32 4, <vscale x 4 x i1> %18, <vscale x 4 x i32> poison), !tbaa !9
  %21 = getelementptr inbounds nuw i32, ptr %1, i64 %16
  %22 = tail call <vscale x 4 x i32> @llvm.masked.load.nxv4i32.p0(ptr %21, i32 4, <vscale x 4 x i1> %18, <vscale x 4 x i32> poison), !tbaa !9
  %23 = mul nsw <vscale x 4 x i32> %22, %20
  %24 = add <vscale x 4 x i32> %23, %17
  %25 = add nuw i64 %16, %14
  %26 = icmp eq i64 %25, %12
  br i1 %26, label %27, label %15, !llvm.loop !13

27:                                               ; preds = %15
  %28 = select <vscale x 4 x i1> %18, <vscale x 4 x i32> %24, <vscale x 4 x i32> %17
  %29 = tail call i32 @llvm.vector.reduce.add.nxv4i32(<vscale x 4 x i32> %28)
  br label %30

30:                                               ; preds = %27, %3
  %31 = phi i32 [ 0, %3 ], [ %29, %27 ]
  ret i32 %31
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(none) uwtable vscale_range(2,1024)
define dso_local noundef signext i32 @max3(i32 noundef signext %0, i32 noundef signext %1, i32 noundef signext %2) local_unnamed_addr #1 {
  %4 = tail call i32 @llvm.smax.i32(i32 %1, i32 %0)
  %5 = tail call i32 @llvm.smax.i32(i32 %2, i32 %4)
  ret i32 %5
}

; Function Attrs: nofree norecurse nosync nounwind optsize memory(argmem: read) uwtable vscale_range(2,1024)
define dso_local i64 @sumld(ptr noundef readonly captures(none) %0, i64 noundef %1) local_unnamed_addr #0 {
  %3 = icmp sgt i64 %1, 0
  br i1 %3, label %4, label %25

4:                                                ; preds = %2
  %5 = tail call i64 @llvm.vscale.i64()
  %6 = shl nuw nsw i64 %5, 1
  %7 = add nsw i64 %6, -1
  %8 = add i64 %1, %7
  %9 = sub nsw i64 0, %6
  %10 = and i64 %8, %9
  %11 = tail call i64 @llvm.vscale.i64()
  %12 = shl nuw nsw i64 %11, 1
  br label %13

13:                                               ; preds = %13, %4
  %14 = phi i64 [ 0, %4 ], [ %20, %13 ]
  %15 = phi <vscale x 2 x i64> [ zeroinitializer, %4 ], [ %19, %13 ]
  %16 = tail call <vscale x 2 x i1> @llvm.get.active.lane.mask.nxv2i1.i64(i64 %14, i64 %1)
  %17 = getelementptr inbounds nuw i64, ptr %0, i64 %14
  %18 = tail call <vscale x 2 x i64> @llvm.masked.load.nxv2i64.p0(ptr %17, i32 8, <vscale x 2 x i1> %16, <vscale x 2 x i64> poison), !tbaa !17
  %19 = add <vscale x 2 x i64> %18, %15
  %20 = add i64 %14, %12
  %21 = icmp eq i64 %20, %10
  br i1 %21, label %22, label %13, !llvm.loop !19

22:                                               ; preds = %13
  %23 = select <vscale x 2 x i1> %16, <vscale x 2 x i64> %19, <vscale x 2 x i64> %15
  %24 = tail call i64 @llvm.vector.reduce.add.nxv2i64(<vscale x 2 x i64> %23)
  br label %25

25:                                               ; preds = %22, %2
  %26 = phi i64 [ 0, %2 ], [ %24, %22 ]
  ret i64 %26
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(none) uwtable vscale_range(2,1024)
define dso_local signext range(i32 0, 5) i32 @sw(i32 noundef signext %0) local_unnamed_addr #1 {
  %2 = icmp ult i32 %0, 3
  br i1 %2, label %3, label %7

3:                                                ; preds = %1
  %4 = zext nneg i32 %0 to i64
  %5 = getelementptr inbounds nuw [3 x i32], ptr @switch.table.sw, i64 0, i64 %4
  %6 = load i32, ptr %5, align 4
  br label %7

7:                                                ; preds = %1, %3
  %8 = phi i32 [ %6, %3 ], [ 0, %1 ]
  ret i32 %8
}

; Function Attrs: nofree norecurse nosync nounwind optsize memory(argmem: read) uwtable vscale_range(2,1024)
define dso_local signext i32 @cnt(ptr noundef readonly captures(none) %0, i32 noundef signext %1, i32 noundef signext %2) local_unnamed_addr #0 {
  %4 = icmp eq i32 %1, 0
  br i1 %4, label %31, label %5

5:                                                ; preds = %3
  %6 = zext i32 %1 to i64
  %7 = tail call i64 @llvm.vscale.i64()
  %8 = shl nuw nsw i64 %7, 2
  %9 = add nsw i64 %8, -1
  %10 = add nsw i64 %9, %6
  %11 = sub nsw i64 0, %8
  %12 = and i64 %10, %11
  %13 = tail call i64 @llvm.vscale.i64()
  %14 = shl nuw nsw i64 %13, 2
  %15 = insertelement <vscale x 4 x i32> poison, i32 %2, i64 0
  %16 = shufflevector <vscale x 4 x i32> %15, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  br label %17

17:                                               ; preds = %17, %5
  %18 = phi i64 [ 0, %5 ], [ %26, %17 ]
  %19 = phi <vscale x 4 x i32> [ zeroinitializer, %5 ], [ %25, %17 ]
  %20 = tail call <vscale x 4 x i1> @llvm.get.active.lane.mask.nxv4i1.i64(i64 %18, i64 %6)
  %21 = getelementptr inbounds nuw i32, ptr %0, i64 %18
  %22 = tail call <vscale x 4 x i32> @llvm.masked.load.nxv4i32.p0(ptr %21, i32 4, <vscale x 4 x i1> %20, <vscale x 4 x i32> poison), !tbaa !9
  %23 = icmp eq <vscale x 4 x i32> %22, %16
  %24 = zext <vscale x 4 x i1> %23 to <vscale x 4 x i32>
  %25 = add <vscale x 4 x i32> %19, %24
  %26 = add nuw i64 %18, %14
  %27 = icmp eq i64 %26, %12
  br i1 %27, label %28, label %17, !llvm.loop !20

28:                                               ; preds = %17
  %29 = select <vscale x 4 x i1> %20, <vscale x 4 x i32> %25, <vscale x 4 x i32> %19
  %30 = tail call i32 @llvm.vector.reduce.add.nxv4i32(<vscale x 4 x i32> %29)
  br label %31

31:                                               ; preds = %28, %3
  %32 = phi i32 [ 0, %3 ], [ %30, %28 ]
  ret i32 %32
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(none) uwtable vscale_range(2,1024)
define dso_local noundef signext i32 @sat(i32 noundef signext %0, i32 noundef signext %1, i32 noundef signext %2) local_unnamed_addr #1 {
  %4 = icmp slt i32 %0, %1
  %5 = tail call i32 @llvm.smin.i32(i32 %0, i32 %2)
  %6 = select i1 %4, i32 %1, i32 %5
  ret i32 %6
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(none) uwtable vscale_range(2,1024)
define dso_local i64 @mix(i64 noundef %0, i64 noundef %1, i64 noundef %2) local_unnamed_addr #1 {
  %4 = mul nsw i64 %1, %0
  %5 = mul nsw i64 %2, 3
  %6 = xor i64 %1, %0
  %7 = add i64 %6, %4
  %8 = add i64 %7, %5
  %9 = shl i64 %2, 1
  %10 = sub i64 %8, %9
  ret i64 %10
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(none) uwtable vscale_range(2,1024)
define dso_local signext range(i32 0, -2147483648) i32 @cond(i32 noundef signext %0, i32 noundef signext %1) local_unnamed_addr #1 {
  %3 = sub nsw i32 %0, %1
  %4 = tail call i32 @llvm.abs.i32(i32 %3, i1 true)
  ret i32 %4
}

; Function Attrs: nofree norecurse nosync nounwind optsize memory(argmem: read) uwtable vscale_range(2,1024)
define dso_local i64 @walk(ptr noundef readonly captures(none) %0, i64 noundef %1) local_unnamed_addr #0 {
  %3 = icmp sgt i64 %1, 0
  br i1 %3, label %4, label %28

4:                                                ; preds = %2
  %5 = tail call i64 @llvm.vscale.i64()
  %6 = shl nuw nsw i64 %5, 1
  %7 = add nsw i64 %6, -1
  %8 = add i64 %1, %7
  %9 = sub nsw i64 0, %6
  %10 = and i64 %8, %9
  %11 = tail call i64 @llvm.vscale.i64()
  %12 = shl nuw nsw i64 %11, 1
  br label %13

13:                                               ; preds = %13, %4
  %14 = phi i64 [ 0, %4 ], [ %23, %13 ]
  %15 = phi <vscale x 2 x i64> [ zeroinitializer, %4 ], [ %22, %13 ]
  %16 = tail call <vscale x 2 x i1> @llvm.get.active.lane.mask.nxv2i1.i64(i64 %14, i64 %1)
  %17 = getelementptr inbounds nuw i64, ptr %0, i64 %14
  %18 = tail call <vscale x 2 x i64> @llvm.masked.load.nxv2i64.p0(ptr %17, i32 8, <vscale x 2 x i1> %16, <vscale x 2 x i64> poison), !tbaa !17
  %19 = mul nsw <vscale x 2 x i64> %18, splat (i64 3)
  %20 = ashr <vscale x 2 x i64> %18, splat (i64 2)
  %21 = add <vscale x 2 x i64> %20, %15
  %22 = add <vscale x 2 x i64> %21, %19
  %23 = add i64 %14, %12
  %24 = icmp eq i64 %23, %10
  br i1 %24, label %25, label %13, !llvm.loop !21

25:                                               ; preds = %13
  %26 = select <vscale x 2 x i1> %16, <vscale x 2 x i64> %22, <vscale x 2 x i64> %15
  %27 = tail call i64 @llvm.vector.reduce.add.nxv2i64(<vscale x 2 x i64> %26)
  br label %28

28:                                               ; preds = %25, %2
  %29 = phi i64 [ 0, %2 ], [ %27, %25 ]
  ret i64 %29
}

; Function Attrs: nofree norecurse nosync nounwind optsize memory(none) uwtable vscale_range(2,1024)
define dso_local signext i32 @popcntish(i32 noundef signext %0) local_unnamed_addr #2 {
  %2 = icmp eq i32 %0, 0
  br i1 %2, label %10, label %3

3:                                                ; preds = %1, %3
  %4 = phi i32 [ %7, %3 ], [ 0, %1 ]
  %5 = phi i32 [ %8, %3 ], [ %0, %1 ]
  %6 = and i32 %5, 1
  %7 = add i32 %4, %6
  %8 = lshr i32 %5, 1
  %9 = icmp ult i32 %5, 2
  br i1 %9, label %10, label %3, !llvm.loop !22

10:                                               ; preds = %3, %1
  %11 = phi i32 [ 0, %1 ], [ %7, %3 ]
  ret i32 %11
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(none) uwtable vscale_range(2,1024)
define dso_local signext i32 @mul3(i32 noundef signext %0) local_unnamed_addr #1 {
  %2 = mul nsw i32 %0, 3
  ret i32 %2
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.smin.i32(i32, i32) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.smax.i32(i32, i32) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.abs.i32(i32, i1 immarg) #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare i64 @llvm.vscale.i64() #4

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare <vscale x 4 x i1> @llvm.get.active.lane.mask.nxv4i1.i64(i64, i64) #4

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: read)
declare <vscale x 4 x i32> @llvm.masked.load.nxv4i32.p0(ptr captures(none), i32 immarg, <vscale x 4 x i1>, <vscale x 4 x i32>) #5

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.vector.reduce.add.nxv4i32(<vscale x 4 x i32>) #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare <vscale x 2 x i1> @llvm.get.active.lane.mask.nxv2i1.i64(i64, i64) #4

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: read)
declare <vscale x 2 x i64> @llvm.masked.load.nxv2i64.p0(ptr captures(none), i32 immarg, <vscale x 2 x i1>, <vscale x 2 x i64>) #5

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.vector.reduce.add.nxv2i64(<vscale x 2 x i64>) #3

attributes #0 = { nofree norecurse nosync nounwind optsize memory(argmem: read) uwtable vscale_range(2,1024) "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic-rv64" "target-features"="+64bit,+a,+b,+c,+d,+f,+m,+relax,+supm,+v,+za64rs,+zaamo,+zalrsc,+zawrs,+zba,+zbb,+zbs,+zca,+zcb,+zcd,+zcmop,+zfa,+zfhmin,+zic64b,+zicbom,+zicbop,+zicboz,+ziccamoa,+ziccif,+zicclsm,+ziccrse,+zicntr,+zicond,+zicsr,+zifencei,+zihintntl,+zihintpause,+zihpm,+zimop,+zkt,+zmmul,+zvbb,+zve32f,+zve32x,+zve64d,+zve64f,+zve64x,+zvfhmin,+zvkb,+zvkt,+zvl128b,+zvl32b,+zvl64b,-e,-experimental-p,-experimental-smctr,-experimental-ssctr,-experimental-svukte,-experimental-xqccmp,-experimental-xqcia,-experimental-xqciac,-experimental-xqcibi,-experimental-xqcibm,-experimental-xqcicli,-experimental-xqcicm,-experimental-xqcics,-experimental-xqcicsr,-experimental-xqciint,-experimental-xqciio,-experimental-xqcilb,-experimental-xqcili,-experimental-xqcilia,-experimental-xqcilo,-experimental-xqcilsm,-experimental-xqcisim,-experimental-xqcisls,-experimental-xqcisync,-experimental-xrivosvisni,-experimental-xrivosvizip,-experimental-xsfmclic,-experimental-xsfsclic,-experimental-zalasr,-experimental-zicfilp,-experimental-zicfiss,-experimental-zvbc32e,-experimental-zvkgs,-experimental-zvqdotq,-h,-q,-sdext,-sdtrig,-sha,-shcounterenw,-shgatpa,-shlcofideleg,-shtvala,-shvsatpa,-shvstvala,-shvstvecd,-smaia,-smcdeleg,-smcntrpmf,-smcsrind,-smdbltrp,-smepmp,-smmpm,-smnpm,-smrnmi,-smstateen,-ssaia,-ssccfg,-ssccptr,-sscofpmf,-sscounterenw,-sscsrind,-ssdbltrp,-ssnpm,-sspm,-ssqosid,-ssstateen,-ssstrict,-sstc,-sstvala,-sstvecd,-ssu64xl,-svade,-svadu,-svbare,-svinval,-svnapot,-svpbmt,-svvptc,-xandesbfhcvt,-xandesperf,-xandesvbfhcvt,-xandesvdot,-xandesvpackfph,-xandesvsintload,-xcvalu,-xcvbi,-xcvbitmanip,-xcvelw,-xcvmac,-xcvmem,-xcvsimd,-xmipscbop,-xmipscmov,-xmipslsp,-xsfcease,-xsfmm128t,-xsfmm16t,-xsfmm32a16f,-xsfmm32a32f,-xsfmm32a8f,-xsfmm32a8i,-xsfmm32t,-xsfmm64a64f,-xsfmm64t,-xsfmmbase,-xsfvcp,-xsfvfnrclipxfqf,-xsfvfwmaccqqq,-xsfvqmaccdod,-xsfvqmaccqoq,-xsifivecdiscarddlone,-xsifivecflushdlone,-xtheadba,-xtheadbb,-xtheadbs,-xtheadcmo,-xtheadcondmov,-xtheadfmemidx,-xtheadmac,-xtheadmemidx,-xtheadmempair,-xtheadsync,-xtheadvdot,-xventanacondops,-xwchc,-za128rs,-zabha,-zacas,-zama16b,-zbc,-zbkb,-zbkc,-zbkx,-zce,-zcf,-zclsd,-zcmp,-zcmt,-zdinx,-zfbfmin,-zfh,-zfinx,-zhinx,-zhinxmin,-ziccamoc,-zilsd,-zk,-zkn,-zknd,-zkne,-zknh,-zkr,-zks,-zksed,-zksh,-ztso,-zvbc,-zvfbfmin,-zvfbfwma,-zvfh,-zvkg,-zvkn,-zvknc,-zvkned,-zvkng,-zvknha,-zvknhb,-zvks,-zvksc,-zvksed,-zvksg,-zvksh,-zvl1024b,-zvl16384b,-zvl2048b,-zvl256b,-zvl32768b,-zvl4096b,-zvl512b,-zvl65536b,-zvl8192b" }
attributes #1 = { mustprogress nofree norecurse nosync nounwind optsize willreturn memory(none) uwtable vscale_range(2,1024) "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic-rv64" "target-features"="+64bit,+a,+b,+c,+d,+f,+m,+relax,+supm,+v,+za64rs,+zaamo,+zalrsc,+zawrs,+zba,+zbb,+zbs,+zca,+zcb,+zcd,+zcmop,+zfa,+zfhmin,+zic64b,+zicbom,+zicbop,+zicboz,+ziccamoa,+ziccif,+zicclsm,+ziccrse,+zicntr,+zicond,+zicsr,+zifencei,+zihintntl,+zihintpause,+zihpm,+zimop,+zkt,+zmmul,+zvbb,+zve32f,+zve32x,+zve64d,+zve64f,+zve64x,+zvfhmin,+zvkb,+zvkt,+zvl128b,+zvl32b,+zvl64b,-e,-experimental-p,-experimental-smctr,-experimental-ssctr,-experimental-svukte,-experimental-xqccmp,-experimental-xqcia,-experimental-xqciac,-experimental-xqcibi,-experimental-xqcibm,-experimental-xqcicli,-experimental-xqcicm,-experimental-xqcics,-experimental-xqcicsr,-experimental-xqciint,-experimental-xqciio,-experimental-xqcilb,-experimental-xqcili,-experimental-xqcilia,-experimental-xqcilo,-experimental-xqcilsm,-experimental-xqcisim,-experimental-xqcisls,-experimental-xqcisync,-experimental-xrivosvisni,-experimental-xrivosvizip,-experimental-xsfmclic,-experimental-xsfsclic,-experimental-zalasr,-experimental-zicfilp,-experimental-zicfiss,-experimental-zvbc32e,-experimental-zvkgs,-experimental-zvqdotq,-h,-q,-sdext,-sdtrig,-sha,-shcounterenw,-shgatpa,-shlcofideleg,-shtvala,-shvsatpa,-shvstvala,-shvstvecd,-smaia,-smcdeleg,-smcntrpmf,-smcsrind,-smdbltrp,-smepmp,-smmpm,-smnpm,-smrnmi,-smstateen,-ssaia,-ssccfg,-ssccptr,-sscofpmf,-sscounterenw,-sscsrind,-ssdbltrp,-ssnpm,-sspm,-ssqosid,-ssstateen,-ssstrict,-sstc,-sstvala,-sstvecd,-ssu64xl,-svade,-svadu,-svbare,-svinval,-svnapot,-svpbmt,-svvptc,-xandesbfhcvt,-xandesperf,-xandesvbfhcvt,-xandesvdot,-xandesvpackfph,-xandesvsintload,-xcvalu,-xcvbi,-xcvbitmanip,-xcvelw,-xcvmac,-xcvmem,-xcvsimd,-xmipscbop,-xmipscmov,-xmipslsp,-xsfcease,-xsfmm128t,-xsfmm16t,-xsfmm32a16f,-xsfmm32a32f,-xsfmm32a8f,-xsfmm32a8i,-xsfmm32t,-xsfmm64a64f,-xsfmm64t,-xsfmmbase,-xsfvcp,-xsfvfnrclipxfqf,-xsfvfwmaccqqq,-xsfvqmaccdod,-xsfvqmaccqoq,-xsifivecdiscarddlone,-xsifivecflushdlone,-xtheadba,-xtheadbb,-xtheadbs,-xtheadcmo,-xtheadcondmov,-xtheadfmemidx,-xtheadmac,-xtheadmemidx,-xtheadmempair,-xtheadsync,-xtheadvdot,-xventanacondops,-xwchc,-za128rs,-zabha,-zacas,-zama16b,-zbc,-zbkb,-zbkc,-zbkx,-zce,-zcf,-zclsd,-zcmp,-zcmt,-zdinx,-zfbfmin,-zfh,-zfinx,-zhinx,-zhinxmin,-ziccamoc,-zilsd,-zk,-zkn,-zknd,-zkne,-zknh,-zkr,-zks,-zksed,-zksh,-ztso,-zvbc,-zvfbfmin,-zvfbfwma,-zvfh,-zvkg,-zvkn,-zvknc,-zvkned,-zvkng,-zvknha,-zvknhb,-zvks,-zvksc,-zvksed,-zvksg,-zvksh,-zvl1024b,-zvl16384b,-zvl2048b,-zvl256b,-zvl32768b,-zvl4096b,-zvl512b,-zvl65536b,-zvl8192b" }
attributes #2 = { nofree norecurse nosync nounwind optsize memory(none) uwtable vscale_range(2,1024) "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic-rv64" "target-features"="+64bit,+a,+b,+c,+d,+f,+m,+relax,+supm,+v,+za64rs,+zaamo,+zalrsc,+zawrs,+zba,+zbb,+zbs,+zca,+zcb,+zcd,+zcmop,+zfa,+zfhmin,+zic64b,+zicbom,+zicbop,+zicboz,+ziccamoa,+ziccif,+zicclsm,+ziccrse,+zicntr,+zicond,+zicsr,+zifencei,+zihintntl,+zihintpause,+zihpm,+zimop,+zkt,+zmmul,+zvbb,+zve32f,+zve32x,+zve64d,+zve64f,+zve64x,+zvfhmin,+zvkb,+zvkt,+zvl128b,+zvl32b,+zvl64b,-e,-experimental-p,-experimental-smctr,-experimental-ssctr,-experimental-svukte,-experimental-xqccmp,-experimental-xqcia,-experimental-xqciac,-experimental-xqcibi,-experimental-xqcibm,-experimental-xqcicli,-experimental-xqcicm,-experimental-xqcics,-experimental-xqcicsr,-experimental-xqciint,-experimental-xqciio,-experimental-xqcilb,-experimental-xqcili,-experimental-xqcilia,-experimental-xqcilo,-experimental-xqcilsm,-experimental-xqcisim,-experimental-xqcisls,-experimental-xqcisync,-experimental-xrivosvisni,-experimental-xrivosvizip,-experimental-xsfmclic,-experimental-xsfsclic,-experimental-zalasr,-experimental-zicfilp,-experimental-zicfiss,-experimental-zvbc32e,-experimental-zvkgs,-experimental-zvqdotq,-h,-q,-sdext,-sdtrig,-sha,-shcounterenw,-shgatpa,-shlcofideleg,-shtvala,-shvsatpa,-shvstvala,-shvstvecd,-smaia,-smcdeleg,-smcntrpmf,-smcsrind,-smdbltrp,-smepmp,-smmpm,-smnpm,-smrnmi,-smstateen,-ssaia,-ssccfg,-ssccptr,-sscofpmf,-sscounterenw,-sscsrind,-ssdbltrp,-ssnpm,-sspm,-ssqosid,-ssstateen,-ssstrict,-sstc,-sstvala,-sstvecd,-ssu64xl,-svade,-svadu,-svbare,-svinval,-svnapot,-svpbmt,-svvptc,-xandesbfhcvt,-xandesperf,-xandesvbfhcvt,-xandesvdot,-xandesvpackfph,-xandesvsintload,-xcvalu,-xcvbi,-xcvbitmanip,-xcvelw,-xcvmac,-xcvmem,-xcvsimd,-xmipscbop,-xmipscmov,-xmipslsp,-xsfcease,-xsfmm128t,-xsfmm16t,-xsfmm32a16f,-xsfmm32a32f,-xsfmm32a8f,-xsfmm32a8i,-xsfmm32t,-xsfmm64a64f,-xsfmm64t,-xsfmmbase,-xsfvcp,-xsfvfnrclipxfqf,-xsfvfwmaccqqq,-xsfvqmaccdod,-xsfvqmaccqoq,-xsifivecdiscarddlone,-xsifivecflushdlone,-xtheadba,-xtheadbb,-xtheadbs,-xtheadcmo,-xtheadcondmov,-xtheadfmemidx,-xtheadmac,-xtheadmemidx,-xtheadmempair,-xtheadsync,-xtheadvdot,-xventanacondops,-xwchc,-za128rs,-zabha,-zacas,-zama16b,-zbc,-zbkb,-zbkc,-zbkx,-zce,-zcf,-zclsd,-zcmp,-zcmt,-zdinx,-zfbfmin,-zfh,-zfinx,-zhinx,-zhinxmin,-ziccamoc,-zilsd,-zk,-zkn,-zknd,-zkne,-zknh,-zkr,-zks,-zksed,-zksh,-ztso,-zvbc,-zvfbfmin,-zvfbfwma,-zvfh,-zvkg,-zvkn,-zvknc,-zvkned,-zvkng,-zvknha,-zvknhb,-zvks,-zvksc,-zvksed,-zvksg,-zvksh,-zvl1024b,-zvl16384b,-zvl2048b,-zvl256b,-zvl32768b,-zvl4096b,-zvl512b,-zvl65536b,-zvl8192b" }
attributes #3 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { nocallback nofree nosync nounwind willreturn memory(none) }
attributes #5 = { nocallback nofree nosync nounwind willreturn memory(argmem: read) }

!llvm.module.flags = !{!0, !1, !2, !4, !5, !6, !7}
!llvm.ident = !{!8}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 1, !"target-abi", !"lp64d"}
!2 = !{i32 6, !"riscv-isa", !3}
!3 = !{!"rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_b1p0_v1p0_zic64b1p0_zicbom1p0_zicbop1p0_zicboz1p0_ziccamoa1p0_ziccif1p0_zicclsm1p0_ziccrse1p0_zicntr2p0_zicond1p0_zicsr2p0_zifencei2p0_zihintntl1p0_zihintpause2p0_zihpm2p0_zimop1p0_zmmul1p0_za64rs1p0_zaamo1p0_zalrsc1p0_zawrs1p0_zfa1p0_zfhmin1p0_zca1p0_zcb1p0_zcd1p0_zcmop1p0_zba1p0_zbb1p0_zbs1p0_zkt1p0_zvbb1p0_zve32f1p0_zve32x1p0_zve64d1p0_zve64f1p0_zve64x1p0_zvfhmin1p0_zvkb1p0_zvkt1p0_zvl128b1p0_zvl32b1p0_zvl64b1p0_supm1p0"}
!4 = !{i32 8, !"PIC Level", i32 2}
!5 = !{i32 7, !"PIE Level", i32 2}
!6 = !{i32 7, !"uwtable", i32 2}
!7 = !{i32 8, !"SmallDataLimit", i32 0}
!8 = !{!"Ubuntu clang version 21.1.8 (6ubuntu1)"}
!9 = !{!10, !10, i64 0}
!10 = !{!"int", !11, i64 0}
!11 = !{!"omnipotent char", !12, i64 0}
!12 = !{!"Simple C/C++ TBAA"}
!13 = distinct !{!13, !14, !15, !16}
!14 = !{!"llvm.loop.mustprogress"}
!15 = !{!"llvm.loop.isvectorized", i32 1}
!16 = !{!"llvm.loop.unroll.runtime.disable"}
!17 = !{!18, !18, i64 0}
!18 = !{!"long", !11, i64 0}
!19 = distinct !{!19, !14, !15, !16}
!20 = distinct !{!20, !14, !15, !16}
!21 = distinct !{!21, !14, !15, !16}
!22 = distinct !{!22, !14}
