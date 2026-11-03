import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'data/station_directory_service.dart';
import 'domain/station_record.dart';

SupabaseClient? metraSupabaseClient;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (supabaseUrl.isNotEmpty && publishableKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: publishableKey);
    metraSupabaseClient = Supabase.instance.client;
  }
  runApp(const MetraWeatherApp());
}


const ink = Color(0xFF102448), navy = Color(0xFF071A43), blue = Color(0xFF1769D2), sky = Color(0xFF46B9F5), canvas = Color(0xFFF3F6FC);
const stations = ['محطة الرياض', 'محطة جدة', 'محطة الدمام', 'محطة تبوك', 'محطة أبها', 'محطة القصيم'];
class MetraWeatherApp extends StatelessWidget {
 const MetraWeatherApp({super.key});
 @override Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner:false,title:'METRA Weather Intelligence',theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:canvas,colorScheme:ColorScheme.fromSeed(seedColor:blue),fontFamily:'Roboto'),home: metraSupabaseClient == null ? const Shell() : const AuthGate());
}
class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState()=>_ShellState(); }
class _ShellState extends State<Shell> {
 int page=0;
 final titles=['الرئيسية','الخريطة','المحطات','التنبيهات','الإعدادات'];
 @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
 body:IndexedStack(index:page,children:const [HomePage(),MapPage(),StationsPage(),AlertsPage(),SettingsPage()]),
 bottomNavigationBar:NavigationBar(height:72,selectedIndex:page,onDestinationSelected:(i)=>setState(()=>page=i),destinations:const [
 NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'الرئيسية'),
 NavigationDestination(icon:Icon(Icons.map_outlined),selectedIcon:Icon(Icons.map),label:'الخريطة'),
 NavigationDestination(icon:Icon(Icons.sensors_outlined),selectedIcon:Icon(Icons.sensors),label:'المحطات'),
 NavigationDestination(icon:Icon(Icons.notifications_none),selectedIcon:Icon(Icons.notifications),label:'التنبيهات'),
 NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:'الإعدادات')]))); }

class HomePage extends StatelessWidget { const HomePage({super.key});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.fromLTRB(18,18,18,28),children:[
 const Header(),const SizedBox(height:12),Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),decoration:BoxDecoration(color:const Color(0xFFFFF3D8),borderRadius:BorderRadius.circular(12)),child:const Row(children:[Icon(Icons.info_outline,color:Color(0xFF9A6700),size:16),SizedBox(width:7),Expanded(child:Text('واجهة تجريبية — القيم المعروضة ليست قراءات طقس حية',style:TextStyle(color:Color(0xFF855B00),fontSize:11,fontWeight:FontWeight.w600)))])),const SizedBox(height:20),const WeatherHero(),const SizedBox(height:20),
 const SectionTitle('توقعات الساعات القادمة','24 ساعة'),
 SizedBox(height:112,child:ListView(scrollDirection:Axis.horizontal,children:const [Hour('الآن','☀','29°',selected:true),Hour('10 ص','☀','30°'),Hour('12 م','⛅','32°'),Hour('3 م','☀','34°'),Hour('6 م','🌤','30°'),Hour('9 م','☾','26°')])),
 const SizedBox(height:22),const SectionTitle('مؤشرات الطقس','تفاصيل'),
 const GridMetric(),const SizedBox(height:20),const SectionTitle('نظرة على الخريطة','فتح'),
 const MapPreview(),const SizedBox(height:20),const SectionTitle('المحطات القريبة','عرض المحطات'),
 const StationStrip(),const SizedBox(height:20),const AlertBanner()]);
}
class Header extends StatelessWidget { const Header({super.key}); @override Widget build(BuildContext context)=>Row(children:[
 Container(width:48,height:48,decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(16)),child:const Icon(Icons.cloud_queue,color:Colors.white,size:29)),
 const SizedBox(width:10),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('METRA',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy,letterSpacing:1.1)),Text('WEATHER INTELLIGENCE',style:TextStyle(fontSize:9,color:Colors.blueGrey,letterSpacing:1.1))])),
 IconButton(onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('مصدر التنبيهات غير متصل حالياً'))),icon:const Icon(Icons.notifications_outlined,color:ink)),const CircleAvatar(backgroundColor:Color(0xFFE1ECFA),child:Icon(Icons.person_outline,color:blue))]);}
class WeatherHero extends StatelessWidget { const WeatherHero({super.key}); @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(30),gradient:const LinearGradient(begin:Alignment.topRight,end:Alignment.bottomLeft,colors:[Color(0xFF123B80),navy]),boxShadow:[BoxShadow(color:navy.withOpacity(.18),blurRadius:24,offset:const Offset(0,12))]),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Row(children:[const Icon(Icons.location_on_outlined,color:Color(0xFFBBD8FF),size:17),const Text('الرياض، المملكة العربية السعودية',style:TextStyle(color:Color(0xFFD6E7FF),fontSize:12)),const Spacer(),Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:Colors.white.withOpacity(.12),borderRadius:BorderRadius.circular(20)),child:const Text('عرض توضيحي',style:TextStyle(color:Colors.white,fontSize:10)))]),
 const SizedBox(height:20),Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('29°',style:TextStyle(color:Colors.white,fontSize:66,fontWeight:FontWeight.w300,height:1)),SizedBox(height:8),Text('غائم جزئياً',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w600)),Text('العظمى 33°  •  الصغرى 21°',style:TextStyle(color:Color(0xFFBBD4F8),fontSize:11))])),const Icon(Icons.wb_cloudy_rounded,color:Color(0xFFFFD66B),size:85)]),
 const SizedBox(height:20),Container(height:1,color:Colors.white24),const SizedBox(height:16),
 const Row(children:[HeroMetric(Icons.water_drop,'62%','الرطوبة'),HeroMetric(Icons.air,'12 km/h','الرياح'),HeroMetric(Icons.visibility,'10 km','الرؤية'),HeroMetric(Icons.compress,'1012','hPa')]) ]));}
class HeroMetric extends StatelessWidget {const HeroMetric(this.icon,this.value,this.label,{super.key});final IconData icon;final String value,label;@override Widget build(BuildContext context)=>Expanded(child:Column(children:[Icon(icon,color:sky,size:19),const SizedBox(height:7),Text(value,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:12)),Text(label,style:const TextStyle(color:Color(0xFFBBD4F8),fontSize:9))]));}
class SectionTitle extends StatelessWidget {const SectionTitle(this.title,this.action,{super.key});final String title,action;@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:12),child:Row(children:[Expanded(child:Text(title,style:const TextStyle(color:ink,fontSize:17,fontWeight:FontWeight.bold))),Text(action,style:const TextStyle(color:blue,fontSize:11,fontWeight:FontWeight.w600))]));}
class Hour extends StatelessWidget {const Hour(this.time,this.symbol,this.temp,{this.selected=false,super.key});final String time,symbol,temp;final bool selected;@override Widget build(BuildContext context)=>Container(width:68,margin:const EdgeInsets.only(left:8),padding:const EdgeInsets.symmetric(vertical:12),decoration:BoxDecoration(color:selected?blue:Colors.white,borderRadius:BorderRadius.circular(19),boxShadow:[BoxShadow(color:ink.withOpacity(.04),blurRadius:9)]),child:Column(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(time,style:TextStyle(color:selected?Colors.white:Colors.blueGrey,fontSize:10)),Text(symbol,style:const TextStyle(fontSize:24)),Text(temp,style:TextStyle(color:selected?Colors.white:ink,fontWeight:FontWeight.bold))]));}
class GridMetric extends StatelessWidget {const GridMetric({super.key});@override Widget build(BuildContext context)=>GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.55,children:const [MetricTile(Icons.thermostat,'درجة الحرارة','29°C','الشعور 31°',Color(0xFFFF9A48)),MetricTile(Icons.air,'سرعة الرياح','12 km/h','شمالية غربية',Color(0xFF27B6D7)),MetricTile(Icons.water_drop,'الرطوبة','62%','مستوى متوسط',Color(0xFF4388F6)),MetricTile(Icons.compress,'الضغط الجوي','1012 hPa','مستقر',Color(0xFF8872E8))]);}
class MetricTile extends StatelessWidget {const MetricTile(this.icon,this.title,this.value,this.note,this.color,{super.key});final IconData icon;final String title,value,note;final Color color;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Row(children:[CircleAvatar(radius:15,backgroundColor:color.withOpacity(.12),child:Icon(icon,color:color,size:17)),const SizedBox(width:7),Expanded(child:Text(title,style:const TextStyle(color:Colors.blueGrey,fontSize:11)))]),Text(value,style:const TextStyle(color:ink,fontSize:18,fontWeight:FontWeight.bold)),Text(note,style:const TextStyle(color:Colors.blueGrey,fontSize:9))]));}
class MapPreview extends StatelessWidget {const MapPreview({super.key});@override Widget build(BuildContext context)=>Container(height:175,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(borderRadius:BorderRadius.circular(24),gradient:const LinearGradient(colors:[Color(0xFFD4E4D6),Color(0xFF9BC6C4),Color(0xFFB7D5A6)])),child:Stack(children:[Positioned(left:-30,top:45,child:Transform.rotate(angle:-.3,child:Container(width:300,height:48,color:Colors.white.withOpacity(.4)))),Positioned(left:75,top:40,child:const MapDot()),Positioned(right:85,top:80,child:const MapDot()),Positioned(left:180,bottom:30,child:const MapDot()),const Center(child:Icon(Icons.layers_outlined,color:Colors.white,size:38)),Positioned(right:12,bottom:12,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:const Text('عرض الرادار',style:TextStyle(color:navy,fontSize:11,fontWeight:FontWeight.bold))))]));}
class MapDot extends StatelessWidget {const MapDot({super.key});@override Widget build(BuildContext context)=>Container(width:24,height:24,decoration:BoxDecoration(color:blue,borderRadius:BorderRadius.circular(9),border:Border.all(color:Colors.white,width:2),boxShadow:[BoxShadow(color:blue.withOpacity(.4),blurRadius:8)]),child:const Icon(Icons.location_on,color:Colors.white,size:14));}
class StationStrip extends StatelessWidget {const StationStrip({super.key});@override Widget build(BuildContext context)=>SizedBox(height:94,child:ListView(scrollDirection:Axis.horizontal,children:stations.take(4).map((s)=>Container(width:150,margin:const EdgeInsets.only(left:9),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.sensors,color:blue,size:17),Spacer(),Icon(Icons.circle,color:Colors.green,size:8)]),const Spacer(),Text(s,style:const TextStyle(color:ink,fontWeight:FontWeight.bold,fontSize:12)),const Text('بيانات واجهة تجريبية',style:TextStyle(color:Colors.blueGrey,fontSize:9))]))).toList()));}
class AlertBanner extends StatelessWidget {const AlertBanner({super.key});@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:const LinearGradient(colors:[navy,Color(0xFF174C98)])),child:const Row(children:[Icon(Icons.notifications_active_outlined,color:Color(0xFFFFD66B),size:28),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('التنبيهات الذكية',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),Text('ابقَ على اطلاع بتغيرات الطقس',style:TextStyle(color:Color(0xFFBFD7FA),fontSize:11))])),Icon(Icons.chevron_left,color:Colors.white)]));}

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Future<List<StationRecord>>? future;
  @override
  void initState() {
    super.initState();
    final client = metraSupabaseClient;
    if (client != null) future = StationDirectoryService(client).fetchStations();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'خريطة الطقس',
    subtitle: 'مواقع المحطات المسجلة ذات الإحداثيات المتاحة',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 430,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: future == null
            ? const _MapUnavailable(message: 'فعّل إعدادات Supabase لعرض مواقع المحطات المسجلة.')
            : FutureBuilder<List<StationRecord>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const _MapUnavailable(message: 'تعذر تحميل مواقع المحطات. تحقق من اعتماد الحساب.');
                  }
                  final stations = (snapshot.data ?? const <StationRecord>[])
                      .where((station) => station.hasCoordinates).toList(growable: false);
                  if (stations.isEmpty) {
                    return const _MapUnavailable(message: 'لا توجد إحداثيات متاحة للعرض ضمن الدليل.');
                  }
                  final markers = stations.map((station) => Marker(
                    point: LatLng(station.latitude!, station.longitude!),
                    width: 44, height: 54,
                    child: Tooltip(
                      message: '${station.name} • ${station.typeLabel}',
                      child: Icon(
                        station.isClassic ? Icons.location_on : Icons.sensors,
                        size: 38,
                        color: station.isClassic ? const Color(0xFFD28A19) : blue,
                        shadows: const [Shadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))],
                      ),
                    ),
                  )).toList(growable: false);
                  final first = stations.first;
                  return FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(first.latitude!, first.longitude!),
                      initialZoom: 5.2,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.metra.weather_intelligence',
                        maxNativeZoom: 19,
                      ),
                      MarkerLayer(markers: markers),
                      RichAttributionWidget(
                        attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
                      ),
                    ],
                  );
                },
              ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 14, runSpacing: 8, children: const [
        _MapLegend(color: Color(0xFFD28A19), label: 'محطة كلاسيكية'),
        _MapLegend(color: blue, label: 'محطة آلية'),
      ]),
      const SizedBox(height: 12),
      FutureBuilder<List<StationRecord>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final records = snapshot.data!;
          final located = records.where((station) => station.hasCoordinates).length;
          return Text(
            '${located} موقعاً على الخريطة من أصل ${records.length} محطة في الدليل. المحطات التي لا تملك إحداثيات لا تُحذف من الدليل.',
            style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
          );
        },
      ),
      const SizedBox(height: 8),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
        onPressed: metraSupabaseClient == null ? null : () => setState(
          () => future = StationDirectoryService(metraSupabaseClient!).fetchStations(),
        ),
        icon: const Icon(Icons.refresh),
        label: const Text('تحديث مواقع المحطات'),
      )),
      const SizedBox(height: 8),
      const Text('الخريطة الأساسية من OpenStreetMap. طبقات الرادار والأمطار والحرارة والرياح لم تُربط بعد.',
        style: TextStyle(color: Colors.blueGrey, fontSize: 11)),
    ]),
  );
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE8EFF8),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.map_outlined, size: 42, color: navy),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(color: ink)),
    ]),
  );
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.location_on, color: color, size: 19),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
  ]);
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final client = metraSupabaseClient!;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) => client.auth.currentSession != null
          ? const Shell()
          : const SignInPage(),
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  Future<void> signIn() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'أدخل البريد الإلكتروني وكلمة المرور.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await metraSupabaseClient!.auth.signInWithPassword(
        email: email.text.trim(), password: password.text,
      );
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'تعذر تسجيل الدخول حالياً. تحقق من الاتصال.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_queue, color: navy, size: 64),
          const SizedBox(height: 12),
          const Text('METRA', style: TextStyle(color: navy, fontSize: 30, fontWeight: FontWeight.w900)),
          const Text('تسجيل الدخول إلى منصة الأرصاد الجوية'),
          const SizedBox(height: 28),
          TextField(controller: email, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
            onSubmitted: (_) => signIn()),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12),
            child: Text(error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: busy ? null : signIn,
            child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('تسجيل الدخول'))),
          const SizedBox(height: 12),
          const Text('تخضع الحسابات للتحقق واعتماد الصلاحيات قبل الوصول إلى بيانات المحطات.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
        ]),
      ),
    ))),
  );
}

class StationsPage extends StatefulWidget {
  const StationsPage({super.key});
  @override
  State<StationsPage> createState() => _StationsPageState();
}

class _StationsPageState extends State<StationsPage> {
  Future<List<StationRecord>>? future;
  String filter = 'الكل';

  @override
  void initState() {
    super.initState();
    final client = metraSupabaseClient;
    if (client != null) future = StationDirectoryService(client).fetchStations();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'محطات الرصد',
    subtitle: 'الدليل الموحد للمحطات الكلاسيكية والآلية',
    child: future == null
      ? const _StationMessage(icon: Icons.cloud_off_outlined,
          title: 'خدمة المحطات غير مهيأة',
          message: 'شغّل التطبيق مع إعدادات Supabase للوصول إلى دليل المحطات. لا تُعرض بيانات تجريبية على أنها بيانات تشغيلية.')
      : FutureBuilder<List<StationRecord>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return _StationMessage(
                icon: Icons.lock_outline,
                title: 'تعذر الوصول إلى الدليل',
                message: 'الحساب يحتاج إلى الاعتماد أو لا تتوفر صلاحية الوصول. تحقق من الحساب والاتصال.',
                onRetry: () => setState(() => future = StationDirectoryService(metraSupabaseClient!).fetchStations()),
              );
            }
            final all = snapshot.data ?? const <StationRecord>[];
            final visible = all.where((station) =>
              filter == 'الكل' ||
              (filter == 'كلاسيكية' && station.isClassic) ||
              (filter == 'آلية' && !station.isClassic)).toList(growable: false);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('الدليل الموحد', style: TextStyle(color: ink, fontWeight: FontWeight.bold))),
                IconButton(
                  tooltip: 'تحديث الدليل',
                  onPressed: () => setState(() => future = StationDirectoryService(metraSupabaseClient!).fetchStations()),
                  icon: const Icon(Icons.refresh, color: blue),
                ),
              ]),
              Wrap(spacing: 8, children: [
                for (final item in ['الكل', 'كلاسيكية', 'آلية'])
                  ChoiceChip(label: Text(item), selected: filter == item,
                    onSelected: (_) => setState(() => filter = item)),
              ]),
              const SizedBox(height: 12),
              Text('${visible.length} محطة • ${visible.where((s) => s.hasCoordinates).length} بإحداثيات',
                style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
              const SizedBox(height: 10),
              if (visible.isEmpty) const _StationMessage(icon: Icons.sensors_off,
                title: 'لا توجد محطات', message: 'لا توجد سجلات ضمن عامل التصفية المحدد.'),
              for (final station in visible)
                Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)),
                  child: Row(children: [
                    CircleAvatar(
                      backgroundColor: station.isClassic ? const Color(0xFFFFF0DA) : const Color(0xFFE7F1FF),
                      child: Icon(station.isClassic ? Icons.home_work_outlined : Icons.sensors,
                        color: station.isClassic ? const Color(0xFFB97716) : blue)),
                    const SizedBox(width: 11),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(station.name, style: const TextStyle(fontWeight: FontWeight.bold, color: ink)),
                      Text('${station.typeLabel} • ${station.code}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                      Text(station.hasCoordinates
                        ? 'إحداثيات: ${station.latitude!.toStringAsFixed(4)}, ${station.longitude!.toStringAsFixed(4)}'
                        : 'لا تتوفر إحداثيات موثقة', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                    ])),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(station.approvalLabel, style: TextStyle(fontSize: 10,
                        color: station.approvalStatus == 'approved' ? Colors.green : Colors.orange.shade800)),
                      Text(station.operationalStatus == 'active' ? 'فعالة' : 'غير متحقق',
                        style: const TextStyle(fontSize: 9, color: Colors.blueGrey)),
                    ]),
                  ]),
                ),
            ]);
          },
        ),
  );
}

class _StationMessage extends StatelessWidget {
  const _StationMessage({required this.icon, required this.title, required this.message, this.onRetry});
  final IconData icon;
  final String title, message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Column(children: [
      Icon(icon, color: blue, size: 36), const SizedBox(height: 10),
      Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.bold)),
      const SizedBox(height: 7),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
      if (onRetry != null) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
      ],
    ]),
  );
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'التنبيهات',
    subtitle: 'مركز التنبيهات الجوية',
    child: Column(children: [
      const AlertBanner(),
      const SizedBox(height: 15),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6EAF0)),
        ),
        child: Column(children: [
          const Icon(Icons.cloud_off_outlined, color: blue, size: 36),
          const SizedBox(height: 10),
          const Text('مصدر التنبيهات غير متصل',
            style: TextStyle(color: ink, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'لم يتم ربط مصدر رسمي للتنبيهات الجوية بعد. لا يمكن تأكيد وجود تنبيهات أو عدم وجودها حالياً.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          const Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
            children: [
              Chip(label: Text('الحرارة')),
              Chip(label: Text('الرياح')),
              Chip(label: Text('الأمطار')),
            ]),
        ]),
      ),
    ]),
  );
}
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool signingOut = false;

  Future<void> signOut() async {
    final client = metraSupabaseClient;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تسجيل الخروج متاح بعد تهيئة Supabase.')),
      );
      return;
    }
    setState(() => signingOut = true);
    try {
      await client.auth.signOut();
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل الخروج: ${e.message}')),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تسجيل الخروج. تحقق من الاتصال.')),
      );
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'الإعدادات',
    subtitle: 'تخصيص تجربة METRA',
    child: Column(children: [
      for (final s in ['المدينة الافتراضية', 'وحدات الحرارة', 'وحدات سرعة الرياح', 'إشعارات الطقس', 'اللغة', 'حول التطبيق'])
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.tune, color: blue),
              title: Text(s),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$s: لم يتم ربط هذا الخيار بعد')),
              ),
            ),
          ),
        ),
      if (metraSupabaseClient != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: signingOut ? null : signOut,
            icon: signingOut
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.logout),
            label: Text(signingOut ? 'جارٍ تسجيل الخروج' : 'تسجيل الخروج'),
          )),
        ),
    ]),
  );
}
class PageFrame extends StatelessWidget {const PageFrame({super.key,required this.title,required this.subtitle,required this.child});final String title,subtitle;final Widget child;@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.fromLTRB(18,22,18,30),children:[const Header(),const SizedBox(height:25),Text(title,style:const TextStyle(color:ink,fontSize:25,fontWeight:FontWeight.bold)),const SizedBox(height:5),Text(subtitle,style:const TextStyle(color:Colors.blueGrey,fontSize:12)),const SizedBox(height:22),child]);}
