import base
#import basicOps
import complexNumbers
#import complexType
import matrixConcept
import types

proc determinantN*(a: any): auto =
  const nc = a.nrows
  var c {.noInit.}: type(a)
  var row: array[nc,int]
  var nswaps = 0
  var r: type(a[0,0])
  r := 1

  for i in 0..<nc:
    for j in 0..<nc:
      c[i,j] = a[i,j]
    row[i] = i

  for j in 0..<nc:
    if j>0:
      for i in j..<nc:
        var t2 = c[i,j]
        for k in 0..<j:
          t2 -= c[i,k] * c[k,j]
        c[i,j] := t2

    var rmax = c[j,j].norm2
    #[
    var kmax = j
    for k in (j+1)..<nc:
      var rn = c[k,j].norm2
      if rn>rmax:
        rmax = rn
        kmax = k
    if rmax==0: # matrix is singular
      r := 0
      return r
    if kmax != j:
      swap(row[j], row[kmax])
      inc nswaps
    ]#

    r *= c[j,j]

    let ri = 1.0/rmax
    var Cjji = ri * c[j,j]
    for i in (j+1)..<nc:
      var t2 = c[j,i]
      for k in 0..<j:
        t2 -= c[j,k] * c[k,i]
      c[j,i] := t2 * Cjji

  if (nswaps and 1) != 0:
    r := -r

  r

proc determinant*(x: any): auto =
  assert(x.nrows == x.ncols)
  when x.nrows==1:
    result = x[0,0]
  elif x.nrows==2:
    optimizeAst:
      result = x[0,0]*x[1,1] - x[0,1]*x[1,0]
  elif x.nrows==3:
    result = (x[0,0]*x[1,1]-x[0,1]*x[1,0])*x[2,2] +
             (x[0,2]*x[1,0]-x[0,0]*x[1,2])*x[2,1] +
             (x[0,1]*x[1,2]-x[0,2]*x[1,1])*x[2,0]
  else:
    result = determinantN(x)

template rsqrtPHM2(r:typed; x:typed):untyped =
  let x00 = x[0,0].re
  let x11 = x[1,1].re
  let x01 = 0.5*(x[0,1]+adj(x[1,0]))
  let det = abs(x00*x11 - x01.norm2)
  let tr = x00 + x11
  let sdet = sqrt(det)
  let trsdet = tr + sdet
  let c1 = 1/(sdet*sqrt(trsdet+sdet))
  let c0 = trsdet*c1
  r := c0 - c1*x

proc rsqrtPHM3f(c0,c1,c2:var any; tr,p2,det:any) =
  mixin sin,cos,acos
  let tr3 = (1.0/3.0)*tr
  let p23 = (1.0/3.0)*p2
  let tr32 = tr3*tr3
  let q = abs(0.5*(p23-tr32))
  let r = 0.25*tr3*(5*tr32-p2) - 0.5*det
  let sq = sqrt(q)
  let sq3 = q*sq
  #let rsq3 = r/sq3
  #var minv,maxv {.noinit.}:type(rsq3)
  #minv := -1.0
  #maxv := 1.0
  #let rsq3r = min(maxv, max(minv,rsq3))
  let isq3 = 1.0/sq3
  var minv,maxv {.noinit.}: type(isq3)
  maxv := 3e38
  minv := -3e38
  let isq3c = min(maxv, max(minv,isq3))
  let rsq3c = r * isq3c
  maxv := 1
  minv := -1
  let rsq3 = min(maxv, max(minv,rsq3c))
  let t = (1.0/3.0)*acos(rsq3)
  let st = sin(t)
  let ct = cos(t)
  let sqc = sq*ct
  let sqs = 1.73205080756887729352*sq*st  # sqrt(3)
  let l0 = tr3 - 2*sqc
  let ll = tr3 + sqc
  let l1 = ll + sqs
  let l2 = ll - sqs
  let sl0 = sqrt(abs(l0))
  let sl1 = sqrt(abs(l1))
  let sl2 = sqrt(abs(l2))
  let u = sl0 + sl1 + sl2
  let w = sl0 * sl1 * sl2
  let d = w*(sl0+sl1)*(sl0+sl2)*(sl1+sl2)
  let di = 1/d
  c0 = (w*u*u+l0*sl0*(l1+l2)+l1*sl1*(l0+l2)+l2*sl2*(l0+l1))*di
  c1 = -(tr*u+w)*di
  c2 = u*di

template rsqrtPHM3(r:typed; x:typed):untyped =
  let tr = trace(x).re
  let x2 = x*x
  let p2 = trace(x2).re
  let det = determinant(x).re
  var c0,c1,c2:type(tr)
  rsqrtPHM3f(c0, c1, c2, tr, p2, det)
  r := c0 + c1*x + c2*x2

template rsqrtPHMN(r:typed; x:typed):untyped =
  var ds = x.norm2
  #if ds == 0.0
  #    M_eq_d(r, 1./0.);
  #    return;
  #  }
  ds = sqrt(ds)

  var e = (0.5*ds)/x - 0.5
  var s = 1 + e

  let estop = epsilon(ds)
  let maxit = 20
  var nit = 0
  while true:
    inc nit
    #let t = (e/s) * e
    #e = -0.5 * t
    let t = e * (s \ e)
    e := -0.5 * t
    s += e
    let enorm = e.norm2
    #//printf("%i enorm = %g\n", nit, enorm);
    if nit>=maxit or enorm<estop: break
  r := x/sqrt(ds)

template rsqrtPHM(r:typed; x:typed):untyped =
  mixin rsqrt
  assert(r.nrows == x.nrows)
  assert(r.ncols == x.ncols)
  assert(r.nrows == r.ncols)
  when r.nrows==1:
    rsqrt(r[0,0].re, x[0,0].re)
    assign(r[0,0].im, 0)
  elif r.nrows==2:
    rsqrtPHM2(r, x)
  elif r.nrows==3:
    rsqrtPHM3(r, x)
  else:
    echo "unimplemented"
    quit(1)
proc rsqrtPH(r:var Mat1; x:Mat2) = rsqrtPHM(r, x)

proc projectU*(r: var Mat1; x: Mat2) =
  let tx = x
  let t = tx.adj * tx
  var t2{.noInit.}: type(t)
  rsqrtPH(t2, t)
  mul(r, tx, t2)

proc projectSU*(r: var Mat1; x: Mat2) =
  const nc = r.nrows
  var m{.noinit.}: type(r)
  m.projectU x
  var d = m.determinant    # already unitary: 1=|d
  let p = (1.0/float(-nc)) * atan2(d.im, d.re)
  d.re = cos p
  d.im = sin p
  r := d * m

proc projectTAH*(r: var Mat1; x: Mat2) =
  r := 0.5*(x-x.adj)
  const nc = x.nrows
  when nc > 1:
    let d = r.trace / nc.float
    r -= d

proc checkSU*(x: Mat1): auto {.inline, noinit.} =
  ## Returns the sum of deviations of x^dag x and det(x) from unitarity.
  var d = norm2(-1.0 + x.adj * x)
  d += norm2(-1.0 + x.determinant)
  return d

discard """
template rsqrtM2(r:typed; x:typed):untyped =
  load(x00, x[0,0].re)
  load(x01, x[0,1])
  #load(x10, x[1,0])
  load(x11, x[1,1].re)
  let det := a00*a11 -
  QLA_r_eq_Re_c_times_c (det, a00, a11);
  QLA_r_meq_Re_c_times_c(det, a01, a10);
  tr = QLA_real(a00) + QLA_real(a11);
  sdet = sqrtP(fabsP(det));
  // c0 = (l2/sl1-l1/sl2)/(l2-l1) = (l2+sl1*sl2+l1)/(sl1*sl2*(sl1+sl2))
  // c1 = (1/sl2-1/sl1)/(l2-l1) = -1/(sl1*sl2*(sl1+sl2))
  c1 = 1/(sdet*sqrtP(fabsP(tr+2*sdet)));
  c0 = (tr+sdet)*c1;
  c1 = -c1;
  // c0 + c1*a
  QLA_c_eq_c_times_r_plus_r(QLA_elem_M(*r,0,0), a00, c1, c0);
  QLA_c_eq_c_times_r(QLA_elem_M(*r,0,1), a01, c1);
  QLA_c_eq_c_times_r(QLA_elem_M(*r,1,0), a10, c1);
  QLA_c_eq_c_times_r_plus_r(QLA_elem_M(*r,1,1), a11, c1, c0);

template rsqrtM(r:typed; x:typed):untyped =
  assert(r.nrows == x.nrows)
  assert(r.ncols == x.ncols)
  assert(r.nrows == r.ncols)
  if r.nrows==1:
    rsqrt(r[0,0], x[0,0])
  elif r.nrows==2:
    rsqrtM2(r, x)
  elif r.nrows==3:
    rsqrtM3(r, x)
  else:
    echo "unimplemented"
    quit(1)
proc rsqrt(r:var Mat1; x:Mat2) = rsqrt(r, x)
"""

proc exp*(m: Mat1): auto {.noInit.} =
  var r{.noInit.}: MatrixArray[m.nrows,m.ncols,type(m[0,0])]
  when m.nrows == 1:
    r := exp(m[0,0])
  else:
    type ft = numberType(m)
    template term(n,x: typed): untyped =
      when x.type is nil.type: 1 + ft(n)*m
      else: 1 + ft(n)*m*x
    #template r3:untyped = nil
    let r12 = term(1.0/12.0, nil)
    let r11 = term(1.0/11.0, r12)
    let r10 = term(1.0/10.0, r11)
    let r9 = term(1.0/9.0, r10)
    let r8 = term(1.0/8.0, r9)
    let r7 = term(1.0/7.0, r8)
    let r6 = term(1.0/6.0, r7)
    let r5 = term(1.0/5.0, r6)
    let r4 = term(1.0/4.0, r5)
    let r3 = term(1.0/3.0, r4)
    let r2 = term(1.0/2.0, r3)
    r := 1 + m*r2
  r
proc ln*(m: Mat1): auto {.noInit.} =
  var r{.noInit.}: MatrixArray[m.nrows,m.ncols,type(m[0,0])]
  when m.nrows == 1:
    r := ln(m[0,0])
  else:
    static: error("ln of matrix not implimented.")
  r

proc re*(m: Mat1): auto {.noInit.} =
  var r{.noInit.}: MatrixArray[m.nrows,m.ncols,type(m[0,0])]
  for i in 0..<m.nrows:
    for j in 0..<m.ncols:
      r[i,j] := re(m[i,j])
  r
proc im*(m: Mat1): auto {.noInit.} =
  var r{.noInit.}: MatrixArray[m.nrows,m.ncols,type(m[0,0])]
  for i in 0..<m.nrows:
    for j in 0..<m.ncols:
      r[i,j] := im(m[i,j])
  r

when isMainModule:
  import macros
  import simd
  template makeTest2(n,f:untyped):untyped =
    proc f[T]:auto =
      const N = n
      type
        Cmplx = ComplexType[T]
        M2 = MatrixArray[N,N,Cmplx]
      var m1,m2,m3,m4:M2
      for i in 0..<N:
        for j in 0..<N:
          #if i==j:
            m1[i,j] = cast[Cmplx](((0.5+i+j-i*j).to(T),(i-j-i*i+j*j).to(T)))
      m2 := m1.adj * m1
      #echo m2
      rsqrtPH(m3, m2)
      #echo m3
      m4 := m3*m2*m3
      let err = sqrt((1-m4).norm2/(N*N))
      echo "test " & $N & " " & $T
      #echo m4
      echo err
      result = err
      projectU(m2, m1)
      m3 := m2.adj*m2
      let err2 = sqrt((1-m3).norm2/(N*N))
      echo "err2: ", err2
      m2 := 0.1*(m2 - (trace(m2)/N))
      m3 := exp(m2)
      echo "exp ",m2,"\n\t= ",m3
  macro makeTest(n:untyped):auto =
    let f = ident("test" & n.repr)
    result = quote do: makeTest2(`n`,`f`)
  makeTest(1)
  makeTest(2)
  makeTest(3)
  block:
    template check(x:untyped):untyped =
      let r = x
      echo "error/eps: ", r/epsilon(r)
      doAssert(abs(r)<128*epsilon(r))
    check(test1[float32]())
    #check(test2[float32]())
    #check(test3[float32]())
    #check(test1[float64]())
    #check(test2[float64]())
    check(test3[float64]())
  block:
    template check(x:untyped):untyped =
      let r0 = x
      let r = simdReduce(r0)/simdLength(r0)
      echo "error/eps: ", r/epsilon(r)
      doAssert(abs(r)<64*epsilon(r))
    template doTest(t:untyped) =
      when declared(t):
        check(test1[t]())
        check(test2[t]())
        check(test3[t]())
    #doTest(SimdS4)
    #doTest(SimdD4)
    #doTest(SimdS8)
    #doTest(SimdD8)
