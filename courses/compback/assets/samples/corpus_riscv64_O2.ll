; ModuleID = 'ir_corpus.c'
source_filename = "ir_corpus.c"
target datalayout = "e-m:e-p:64:64-i64:64-i128:128-n32:64-S128"
target triple = "riscv64-unknown-linux-gnu"

@switch.table.sw = private unnamed_addr constant [3 x i32] [i32 1, i32 2, i32 4], align 4

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable vscale_range(2,1024)
define dso_local signext i32 @dot(ptr noundef readonly captures(none) %0, ptr noundef readonly captures(none) %1, i32 noundef signext %2) local_unnamed_addr #0 {
  %4 = icmp sgt i32 %2, 0
  br i1 %4, label %5, label %33

5:                                                ; preds = %3
  %6 = zext nneg i32 %2 to i64
  %7 = tail call i64 @llvm.vscale.i64()
  %8 = shl nuw nsw i64 %7, 2
  %9 = icmp samesign ugt i64 %8, %6
  br i1 %9, label %30, label %10

10:                                               ; preds = %5
  %11 = tail call i64 @llvm.vscale.i64()
  %12 = mul nuw nsw i64 %11, 2147483644
  %13 = and i64 %12, %6
  %14 = tail call i64 @llvm.vscale.i64()
  %15 = shl nuw nsw i64 %14, 2
  br label %16

16:                                               ; preds = %16, %10
  %17 = phi i64 [ 0, %10 ], [ %25, %16 ]
  %18 = phi <vscale x 4 x i32> [ zeroinitializer, %10 ], [ %24, %16 ]
  %19 = getelementptr inbounds nuw i32, ptr %0, i64 %17
  %20 = load <vscale x 4 x i32>, ptr %19, align 4, !tbaa !9
  %21 = getelementptr inbounds nuw i32, ptr %1, i64 %17
  %22 = load <vscale x 4 x i32>, ptr %21, align 4, !tbaa !9
  %23 = mul nsw <vscale x 4 x i32> %22, %20
  %24 = add <vscale x 4 x i32> %23, %18
  %25 = add nuw i64 %17, %15
  %26 = icmp eq i64 %25, %13
  br i1 %26, label %27, label %16, !llvm.loop !13

27:                                               ; preds = %16
  %28 = tail call i32 @llvm.vector.reduce.add.nxv4i32(<vscale x 4 x i32> %24)
  %29 = icmp eq i64 %13, %6
  br i1 %29, label %33, label %30

30:                                               ; preds = %5, %27
  %31 = phi i64 [ 0, %5 ], [ %13, %27 ]
  %32 = phi i32 [ 0, %5 ], [ %28, %27 ]
  br label %35

33:                                               ; preds = %35, %27, %3
  %34 = phi i32 [ 0, %3 ], [ %28, %27 ], [ %43, %35 ]
  ret i32 %34

35:                                               ; preds = %30, %35
  %36 = phi i64 [ %44, %35 ], [ %31, %30 ]
  %37 = phi i32 [ %43, %35 ], [ %32, %30 ]
  %38 = getelementptr inbounds nuw i32, ptr %0, i64 %36
  %39 = load i32, ptr %38, align 4, !tbaa !9
  %40 = getelementptr inbounds nuw i32, ptr %1, i64 %36
  %41 = load i32, ptr %40, align 4, !tbaa !9
  %42 = mul nsw i32 %41, %39
  %43 = add nsw i32 %42, %37
  %44 = add nuw nsw i64 %36, 1
  %45 = icmp eq i64 %44, %6
  br i1 %45, label %33, label %35, !llvm.loop !17
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable vscale_range(2,1024)
define dso_local noundef signext i32 @max3(i32 noundef signext %0, i32 noundef signext %1, i32 noundef signext %2) local_unnamed_addr #1 {
  %4 = tail call i32 @llvm.smax.i32(i32 %1, i32 %0)
  %5 = tail call i32 @llvm.smax.i32(i32 %2, i32 %4)
  ret i32 %5
}

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable vscale_range(2,1024)
define dso_local i64 @sumld(ptr noundef readonly captures(none) %0, i64 noundef %1) local_unnamed_addr #0 {
  %3 = icmp sgt i64 %1, 0
  br i1 %3, label %4, label %28

4:                                                ; preds = %2
  %5 = tail call i64 @llvm.vscale.i64()
  %6 = shl nuw nsw i64 %5, 1
  %7 = icmp ult i64 %1, %6
  br i1 %7, label %25, label %8

8:                                                ; preds = %4
  %9 = tail call i64 @llvm.vscale.i64()
  %10 = mul nsw i64 %9, -2
  %11 = and i64 %1, %10
  %12 = tail call i64 @llvm.vscale.i64()
  %13 = shl nuw nsw i64 %12, 1
  br label %14

14:                                               ; preds = %14, %8
  %15 = phi i64 [ 0, %8 ], [ %20, %14 ]
  %16 = phi <vscale x 2 x i64> [ zeroinitializer, %8 ], [ %19, %14 ]
  %17 = getelementptr inbounds nuw i64, ptr %0, i64 %15
  %18 = load <vscale x 2 x i64>, ptr %17, align 8, !tbaa !18
  %19 = add <vscale x 2 x i64> %18, %16
  %20 = add nuw i64 %15, %13
  %21 = icmp eq i64 %20, %11
  br i1 %21, label %22, label %14, !llvm.loop !20

22:                                               ; preds = %14
  %23 = tail call i64 @llvm.vector.reduce.add.nxv2i64(<vscale x 2 x i64> %19)
  %24 = icmp eq i64 %1, %11
  br i1 %24, label %28, label %25

25:                                               ; preds = %4, %22
  %26 = phi i64 [ 0, %4 ], [ %11, %22 ]
  %27 = phi i64 [ 0, %4 ], [ %23, %22 ]
  br label %30

28:                                               ; preds = %30, %22, %2
  %29 = phi i64 [ 0, %2 ], [ %23, %22 ], [ %35, %30 ]
  ret i64 %29

30:                                               ; preds = %25, %30
  %31 = phi i64 [ %36, %30 ], [ %26, %25 ]
  %32 = phi i64 [ %35, %30 ], [ %27, %25 ]
  %33 = getelementptr inbounds nuw i64, ptr %0, i64 %31
  %34 = load i64, ptr %33, align 8, !tbaa !18
  %35 = add nsw i64 %34, %32
  %36 = add nuw nsw i64 %31, 1
  %37 = icmp eq i64 %36, %1
  br i1 %37, label %28, label %30, !llvm.loop !21
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable vscale_range(2,1024)
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

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable vscale_range(2,1024)
define dso_local signext i32 @cnt(ptr noundef readonly captures(none) %0, i32 noundef signext %1, i32 noundef signext %2) local_unnamed_addr #0 {
  %4 = icmp eq i32 %1, 0
  br i1 %4, label %34, label %5

5:                                                ; preds = %3
  %6 = zext i32 %1 to i64
  %7 = tail call i64 @llvm.vscale.i64()
  %8 = shl nuw nsw i64 %7, 2
  %9 = icmp samesign ugt i64 %8, %6
  br i1 %9, label %31, label %10

10:                                               ; preds = %5
  %11 = tail call i64 @llvm.vscale.i64()
  %12 = mul nuw nsw i64 %11, 4294967292
  %13 = and i64 %12, %6
  %14 = tail call i64 @llvm.vscale.i64()
  %15 = shl nuw nsw i64 %14, 2
  %16 = insertelement <vscale x 4 x i32> poison, i32 %2, i64 0
  %17 = shufflevector <vscale x 4 x i32> %16, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  br label %18

18:                                               ; preds = %18, %10
  %19 = phi i64 [ 0, %10 ], [ %26, %18 ]
  %20 = phi <vscale x 4 x i32> [ zeroinitializer, %10 ], [ %25, %18 ]
  %21 = getelementptr inbounds nuw i32, ptr %0, i64 %19
  %22 = load <vscale x 4 x i32>, ptr %21, align 4, !tbaa !9
  %23 = icmp eq <vscale x 4 x i32> %22, %17
  %24 = zext <vscale x 4 x i1> %23 to <vscale x 4 x i32>
  %25 = add <vscale x 4 x i32> %20, %24
  %26 = add nuw i64 %19, %15
  %27 = icmp eq i64 %26, %13
  br i1 %27, label %28, label %18, !llvm.loop !22

28:                                               ; preds = %18
  %29 = tail call i32 @llvm.vector.reduce.add.nxv4i32(<vscale x 4 x i32> %25)
  %30 = icmp eq i64 %13, %6
  br i1 %30, label %34, label %31

31:                                               ; preds = %5, %28
  %32 = phi i64 [ 0, %5 ], [ %13, %28 ]
  %33 = phi i32 [ 0, %5 ], [ %29, %28 ]
  br label %36

34:                                               ; preds = %36, %28, %3
  %35 = phi i32 [ 0, %3 ], [ %29, %28 ], [ %43, %36 ]
  ret i32 %35

36:                                               ; preds = %31, %36
  %37 = phi i64 [ %44, %36 ], [ %32, %31 ]
  %38 = phi i32 [ %43, %36 ], [ %33, %31 ]
  %39 = getelementptr inbounds nuw i32, ptr %0, i64 %37
  %40 = load i32, ptr %39, align 4, !tbaa !9
  %41 = icmp eq i32 %40, %2
  %42 = zext i1 %41 to i32
  %43 = add i32 %38, %42
  %44 = add nuw nsw i64 %37, 1
  %45 = icmp eq i64 %44, %6
  br i1 %45, label %34, label %36, !llvm.loop !23
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable vscale_range(2,1024)
define dso_local noundef signext i32 @sat(i32 noundef signext %0, i32 noundef signext %1, i32 noundef signext %2) local_unnamed_addr #1 {
  %4 = icmp slt i32 %0, %1
  %5 = tail call i32 @llvm.smin.i32(i32 %0, i32 %2)
  %6 = select i1 %4, i32 %1, i32 %5
  ret i32 %6
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable vscale_range(2,1024)
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

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable vscale_range(2,1024)
define dso_local signext range(i32 0, -2147483648) i32 @cond(i32 noundef signext %0, i32 noundef signext %1) local_unnamed_addr #1 {
  %3 = sub nsw i32 %0, %1
  %4 = tail call i32 @llvm.abs.i32(i32 %3, i1 true)
  ret i32 %4
}

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable vscale_range(2,1024)
define dso_local i64 @walk(ptr noundef readonly captures(none) %0, i64 noundef %1) local_unnamed_addr #0 {
  %3 = icmp sgt i64 %1, 0
  br i1 %3, label %4, label %31

4:                                                ; preds = %2
  %5 = tail call i64 @llvm.vscale.i64()
  %6 = shl nuw nsw i64 %5, 1
  %7 = icmp ult i64 %1, %6
  br i1 %7, label %28, label %8

8:                                                ; preds = %4
  %9 = tail call i64 @llvm.vscale.i64()
  %10 = mul nsw i64 %9, -2
  %11 = and i64 %1, %10
  %12 = tail call i64 @llvm.vscale.i64()
  %13 = shl nuw nsw i64 %12, 1
  br label %14

14:                                               ; preds = %14, %8
  %15 = phi i64 [ 0, %8 ], [ %23, %14 ]
  %16 = phi <vscale x 2 x i64> [ zeroinitializer, %8 ], [ %22, %14 ]
  %17 = getelementptr inbounds nuw i64, ptr %0, i64 %15
  %18 = load <vscale x 2 x i64>, ptr %17, align 8, !tbaa !18
  %19 = mul nsw <vscale x 2 x i64> %18, splat (i64 3)
  %20 = ashr <vscale x 2 x i64> %18, splat (i64 2)
  %21 = add <vscale x 2 x i64> %20, %16
  %22 = add <vscale x 2 x i64> %21, %19
  %23 = add nuw i64 %15, %13
  %24 = icmp eq i64 %23, %11
  br i1 %24, label %25, label %14, !llvm.loop !24

25:                                               ; preds = %14
  %26 = tail call i64 @llvm.vector.reduce.add.nxv2i64(<vscale x 2 x i64> %22)
  %27 = icmp eq i64 %1, %11
  br i1 %27, label %31, label %28

28:                                               ; preds = %4, %25
  %29 = phi i64 [ 0, %4 ], [ %11, %25 ]
  %30 = phi i64 [ 0, %4 ], [ %26, %25 ]
  br label %33

31:                                               ; preds = %33, %25, %2
  %32 = phi i64 [ 0, %2 ], [ %26, %25 ], [ %41, %33 ]
  ret i64 %32

33:                                               ; preds = %28, %33
  %34 = phi i64 [ %42, %33 ], [ %29, %28 ]
  %35 = phi i64 [ %41, %33 ], [ %30, %28 ]
  %36 = getelementptr inbounds nuw i64, ptr %0, i64 %34
  %37 = load i64, ptr %36, align 8, !tbaa !18
  %38 = mul nsw i64 %37, 3
  %39 = ashr i64 %37, 2
  %40 = add i64 %39, %35
  %41 = add i64 %40, %38
  %42 = add nuw nsw i64 %34, 1
  %43 = icmp eq i64 %42, %1
  br i1 %43, label %31, label %33, !llvm.loop !25
}

; Function Attrs: nofree norecurse nosync nounwind memory(none) uwtable vscale_range(2,1024)
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
  br i1 %9, label %10, label %3, !llvm.loop !26

10:                                               ; preds = %3, %1
  %11 = phi i32 [ 0, %1 ], [ %7, %3 ]
  ret i32 %11
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable vscale_range(2,1024)
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

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.vector.reduce.add.nxv4i32(<vscale x 4 x i32>) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.vector.reduce.add.nxv2i64(<vscale x 2 x i64>) #3

attributes #0 = { nofree norecurse nosync nounwind memory(argmem: read) uwtable vscale_range(2,1024) "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic-rv64" "target-features"="+64bit,+a,+b,+c,+d,+f,+m,+relax,+supm,+v,+za64rs,+zaamo,+zalrsc,+zawrs,+zba,+zbb,+zbs,+zca,+zcb,+zcd,+zcmop,+zfa,+zfhmin,+zic64b,+zicbom,+zicbop,+zicboz,+ziccamoa,+ziccif,+zicclsm,+ziccrse,+zicntr,+zicond,+zicsr,+zifencei,+zihintntl,+zihintpause,+zihpm,+zimop,+zkt,+zmmul,+zvbb,+zve32f,+zve32x,+zve64d,+zve64f,+zve64x,+zvfhmin,+zvkb,+zvkt,+zvl128b,+zvl32b,+zvl64b,-e,-experimental-p,-experimental-smctr,-experimental-ssctr,-experimental-svukte,-experimental-xqccmp,-experimental-xqcia,-experimental-xqciac,-experimental-xqcibi,-experimental-xqcibm,-experimental-xqcicli,-experimental-xqcicm,-experimental-xqcics,-experimental-xqcicsr,-experimental-xqciint,-experimental-xqciio,-experimental-xqcilb,-experimental-xqcili,-experimental-xqcilia,-experimental-xqcilo,-experimental-xqcilsm,-experimental-xqcisim,-experimental-xqcisls,-experimental-xqcisync,-experimental-xrivosvisni,-experimental-xrivosvizip,-experimental-xsfmclic,-experimental-xsfsclic,-experimental-zalasr,-experimental-zicfilp,-experimental-zicfiss,-experimental-zvbc32e,-experimental-zvkgs,-experimental-zvqdotq,-h,-q,-sdext,-sdtrig,-sha,-shcounterenw,-shgatpa,-shlcofideleg,-shtvala,-shvsatpa,-shvstvala,-shvstvecd,-smaia,-smcdeleg,-smcntrpmf,-smcsrind,-smdbltrp,-smepmp,-smmpm,-smnpm,-smrnmi,-smstateen,-ssaia,-ssccfg,-ssccptr,-sscofpmf,-sscounterenw,-sscsrind,-ssdbltrp,-ssnpm,-sspm,-ssqosid,-ssstateen,-ssstrict,-sstc,-sstvala,-sstvecd,-ssu64xl,-svade,-svadu,-svbare,-svinval,-svnapot,-svpbmt,-svvptc,-xandesbfhcvt,-xandesperf,-xandesvbfhcvt,-xandesvdot,-xandesvpackfph,-xandesvsintload,-xcvalu,-xcvbi,-xcvbitmanip,-xcvelw,-xcvmac,-xcvmem,-xcvsimd,-xmipscbop,-xmipscmov,-xmipslsp,-xsfcease,-xsfmm128t,-xsfmm16t,-xsfmm32a16f,-xsfmm32a32f,-xsfmm32a8f,-xsfmm32a8i,-xsfmm32t,-xsfmm64a64f,-xsfmm64t,-xsfmmbase,-xsfvcp,-xsfvfnrclipxfqf,-xsfvfwmaccqqq,-xsfvqmaccdod,-xsfvqmaccqoq,-xsifivecdiscarddlone,-xsifivecflushdlone,-xtheadba,-xtheadbb,-xtheadbs,-xtheadcmo,-xtheadcondmov,-xtheadfmemidx,-xtheadmac,-xtheadmemidx,-xtheadmempair,-xtheadsync,-xtheadvdot,-xventanacondops,-xwchc,-za128rs,-zabha,-zacas,-zama16b,-zbc,-zbkb,-zbkc,-zbkx,-zce,-zcf,-zclsd,-zcmp,-zcmt,-zdinx,-zfbfmin,-zfh,-zfinx,-zhinx,-zhinxmin,-ziccamoc,-zilsd,-zk,-zkn,-zknd,-zkne,-zknh,-zkr,-zks,-zksed,-zksh,-ztso,-zvbc,-zvfbfmin,-zvfbfwma,-zvfh,-zvkg,-zvkn,-zvknc,-zvkned,-zvkng,-zvknha,-zvknhb,-zvks,-zvksc,-zvksed,-zvksg,-zvksh,-zvl1024b,-zvl16384b,-zvl2048b,-zvl256b,-zvl32768b,-zvl4096b,-zvl512b,-zvl65536b,-zvl8192b" }
attributes #1 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable vscale_range(2,1024) "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic-rv64" "target-features"="+64bit,+a,+b,+c,+d,+f,+m,+relax,+supm,+v,+za64rs,+zaamo,+zalrsc,+zawrs,+zba,+zbb,+zbs,+zca,+zcb,+zcd,+zcmop,+zfa,+zfhmin,+zic64b,+zicbom,+zicbop,+zicboz,+ziccamoa,+ziccif,+zicclsm,+ziccrse,+zicntr,+zicond,+zicsr,+zifencei,+zihintntl,+zihintpause,+zihpm,+zimop,+zkt,+zmmul,+zvbb,+zve32f,+zve32x,+zve64d,+zve64f,+zve64x,+zvfhmin,+zvkb,+zvkt,+zvl128b,+zvl32b,+zvl64b,-e,-experimental-p,-experimental-smctr,-experimental-ssctr,-experimental-svukte,-experimental-xqccmp,-experimental-xqcia,-experimental-xqciac,-experimental-xqcibi,-experimental-xqcibm,-experimental-xqcicli,-experimental-xqcicm,-experimental-xqcics,-experimental-xqcicsr,-experimental-xqciint,-experimental-xqciio,-experimental-xqcilb,-experimental-xqcili,-experimental-xqcilia,-experimental-xqcilo,-experimental-xqcilsm,-experimental-xqcisim,-experimental-xqcisls,-experimental-xqcisync,-experimental-xrivosvisni,-experimental-xrivosvizip,-experimental-xsfmclic,-experimental-xsfsclic,-experimental-zalasr,-experimental-zicfilp,-experimental-zicfiss,-experimental-zvbc32e,-experimental-zvkgs,-experimental-zvqdotq,-h,-q,-sdext,-sdtrig,-sha,-shcounterenw,-shgatpa,-shlcofideleg,-shtvala,-shvsatpa,-shvstvala,-shvstvecd,-smaia,-smcdeleg,-smcntrpmf,-smcsrind,-smdbltrp,-smepmp,-smmpm,-smnpm,-smrnmi,-smstateen,-ssaia,-ssccfg,-ssccptr,-sscofpmf,-sscounterenw,-sscsrind,-ssdbltrp,-ssnpm,-sspm,-ssqosid,-ssstateen,-ssstrict,-sstc,-sstvala,-sstvecd,-ssu64xl,-svade,-svadu,-svbare,-svinval,-svnapot,-svpbmt,-svvptc,-xandesbfhcvt,-xandesperf,-xandesvbfhcvt,-xandesvdot,-xandesvpackfph,-xandesvsintload,-xcvalu,-xcvbi,-xcvbitmanip,-xcvelw,-xcvmac,-xcvmem,-xcvsimd,-xmipscbop,-xmipscmov,-xmipslsp,-xsfcease,-xsfmm128t,-xsfmm16t,-xsfmm32a16f,-xsfmm32a32f,-xsfmm32a8f,-xsfmm32a8i,-xsfmm32t,-xsfmm64a64f,-xsfmm64t,-xsfmmbase,-xsfvcp,-xsfvfnrclipxfqf,-xsfvfwmaccqqq,-xsfvqmaccdod,-xsfvqmaccqoq,-xsifivecdiscarddlone,-xsifivecflushdlone,-xtheadba,-xtheadbb,-xtheadbs,-xtheadcmo,-xtheadcondmov,-xtheadfmemidx,-xtheadmac,-xtheadmemidx,-xtheadmempair,-xtheadsync,-xtheadvdot,-xventanacondops,-xwchc,-za128rs,-zabha,-zacas,-zama16b,-zbc,-zbkb,-zbkc,-zbkx,-zce,-zcf,-zclsd,-zcmp,-zcmt,-zdinx,-zfbfmin,-zfh,-zfinx,-zhinx,-zhinxmin,-ziccamoc,-zilsd,-zk,-zkn,-zknd,-zkne,-zknh,-zkr,-zks,-zksed,-zksh,-ztso,-zvbc,-zvfbfmin,-zvfbfwma,-zvfh,-zvkg,-zvkn,-zvknc,-zvkned,-zvkng,-zvknha,-zvknhb,-zvks,-zvksc,-zvksed,-zvksg,-zvksh,-zvl1024b,-zvl16384b,-zvl2048b,-zvl256b,-zvl32768b,-zvl4096b,-zvl512b,-zvl65536b,-zvl8192b" }
attributes #2 = { nofree norecurse nosync nounwind memory(none) uwtable vscale_range(2,1024) "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic-rv64" "target-features"="+64bit,+a,+b,+c,+d,+f,+m,+relax,+supm,+v,+za64rs,+zaamo,+zalrsc,+zawrs,+zba,+zbb,+zbs,+zca,+zcb,+zcd,+zcmop,+zfa,+zfhmin,+zic64b,+zicbom,+zicbop,+zicboz,+ziccamoa,+ziccif,+zicclsm,+ziccrse,+zicntr,+zicond,+zicsr,+zifencei,+zihintntl,+zihintpause,+zihpm,+zimop,+zkt,+zmmul,+zvbb,+zve32f,+zve32x,+zve64d,+zve64f,+zve64x,+zvfhmin,+zvkb,+zvkt,+zvl128b,+zvl32b,+zvl64b,-e,-experimental-p,-experimental-smctr,-experimental-ssctr,-experimental-svukte,-experimental-xqccmp,-experimental-xqcia,-experimental-xqciac,-experimental-xqcibi,-experimental-xqcibm,-experimental-xqcicli,-experimental-xqcicm,-experimental-xqcics,-experimental-xqcicsr,-experimental-xqciint,-experimental-xqciio,-experimental-xqcilb,-experimental-xqcili,-experimental-xqcilia,-experimental-xqcilo,-experimental-xqcilsm,-experimental-xqcisim,-experimental-xqcisls,-experimental-xqcisync,-experimental-xrivosvisni,-experimental-xrivosvizip,-experimental-xsfmclic,-experimental-xsfsclic,-experimental-zalasr,-experimental-zicfilp,-experimental-zicfiss,-experimental-zvbc32e,-experimental-zvkgs,-experimental-zvqdotq,-h,-q,-sdext,-sdtrig,-sha,-shcounterenw,-shgatpa,-shlcofideleg,-shtvala,-shvsatpa,-shvstvala,-shvstvecd,-smaia,-smcdeleg,-smcntrpmf,-smcsrind,-smdbltrp,-smepmp,-smmpm,-smnpm,-smrnmi,-smstateen,-ssaia,-ssccfg,-ssccptr,-sscofpmf,-sscounterenw,-sscsrind,-ssdbltrp,-ssnpm,-sspm,-ssqosid,-ssstateen,-ssstrict,-sstc,-sstvala,-sstvecd,-ssu64xl,-svade,-svadu,-svbare,-svinval,-svnapot,-svpbmt,-svvptc,-xandesbfhcvt,-xandesperf,-xandesvbfhcvt,-xandesvdot,-xandesvpackfph,-xandesvsintload,-xcvalu,-xcvbi,-xcvbitmanip,-xcvelw,-xcvmac,-xcvmem,-xcvsimd,-xmipscbop,-xmipscmov,-xmipslsp,-xsfcease,-xsfmm128t,-xsfmm16t,-xsfmm32a16f,-xsfmm32a32f,-xsfmm32a8f,-xsfmm32a8i,-xsfmm32t,-xsfmm64a64f,-xsfmm64t,-xsfmmbase,-xsfvcp,-xsfvfnrclipxfqf,-xsfvfwmaccqqq,-xsfvqmaccdod,-xsfvqmaccqoq,-xsifivecdiscarddlone,-xsifivecflushdlone,-xtheadba,-xtheadbb,-xtheadbs,-xtheadcmo,-xtheadcondmov,-xtheadfmemidx,-xtheadmac,-xtheadmemidx,-xtheadmempair,-xtheadsync,-xtheadvdot,-xventanacondops,-xwchc,-za128rs,-zabha,-zacas,-zama16b,-zbc,-zbkb,-zbkc,-zbkx,-zce,-zcf,-zclsd,-zcmp,-zcmt,-zdinx,-zfbfmin,-zfh,-zfinx,-zhinx,-zhinxmin,-ziccamoc,-zilsd,-zk,-zkn,-zknd,-zkne,-zknh,-zkr,-zks,-zksed,-zksh,-ztso,-zvbc,-zvfbfmin,-zvfbfwma,-zvfh,-zvkg,-zvkn,-zvknc,-zvkned,-zvkng,-zvknha,-zvknhb,-zvks,-zvksc,-zvksed,-zvksg,-zvksh,-zvl1024b,-zvl16384b,-zvl2048b,-zvl256b,-zvl32768b,-zvl4096b,-zvl512b,-zvl65536b,-zvl8192b" }
attributes #3 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { nocallback nofree nosync nounwind willreturn memory(none) }

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
!17 = distinct !{!17, !14, !16, !15}
!18 = !{!19, !19, i64 0}
!19 = !{!"long", !11, i64 0}
!20 = distinct !{!20, !14, !15, !16}
!21 = distinct !{!21, !14, !16, !15}
!22 = distinct !{!22, !14, !15, !16}
!23 = distinct !{!23, !14, !16, !15}
!24 = distinct !{!24, !14, !15, !16}
!25 = distinct !{!25, !14, !16, !15}
!26 = distinct !{!26, !14}
